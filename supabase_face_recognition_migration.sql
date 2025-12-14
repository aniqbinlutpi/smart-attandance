-- ============================================
-- FACE RECOGNITION MIGRATION
-- Smart Attendance App
-- ============================================
-- Run this script AFTER running supabase_setup.sql
-- This adds face recognition capabilities

-- ============================================
-- 1. ADD FACE RECOGNITION COLUMNS TO USERS
-- ============================================

-- Add face embeddings storage
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS face_embeddings JSONB,
ADD COLUMN IF NOT EXISTS face_registered BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS face_registered_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS face_registration_count INTEGER DEFAULT 0;

-- Add comments for documentation
COMMENT ON COLUMN users.face_embeddings IS 'Stores face embedding vectors as JSON array for face recognition. Format: [{"embedding": [0.1, 0.2, ...], "timestamp": "2024-01-01T00:00:00Z"}]';
COMMENT ON COLUMN users.face_registered IS 'Indicates if user has completed face registration';
COMMENT ON COLUMN users.face_registered_at IS 'Timestamp when face was last registered';
COMMENT ON COLUMN users.face_registration_count IS 'Number of times user has registered their face';

-- ============================================
-- 2. CREATE FACE SCAN LOGS TABLE
-- ============================================

-- Track all face scan attempts for security and debugging
CREATE TABLE IF NOT EXISTS face_scan_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    scan_type TEXT NOT NULL CHECK (scan_type IN ('registration', 'attendance')),
    success BOOLEAN NOT NULL,
    similarity_score DECIMAL(5,4), -- 0.0000 to 1.0000
    error_message TEXT,
    location_lat DECIMAL(10,8),
    location_lng DECIMAL(11,8),
    device_info JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_face_scan_logs_user_id ON face_scan_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_face_scan_logs_created_at ON face_scan_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_face_scan_logs_scan_type ON face_scan_logs(scan_type);
CREATE INDEX IF NOT EXISTS idx_users_face_registered ON users(face_registered);

-- ============================================
-- 3. ENABLE RLS FOR FACE SCAN LOGS
-- ============================================

ALTER TABLE face_scan_logs ENABLE ROW LEVEL SECURITY;

-- Users can view their own scan logs
CREATE POLICY "Users can view own scan logs"
    ON face_scan_logs FOR SELECT
    USING (auth.uid() = user_id);

-- Users can create their own scan logs
CREATE POLICY "Users can create own scan logs"
    ON face_scan_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Admins can view all scan logs
CREATE POLICY "Admins can view all scan logs"
    ON face_scan_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.role = 'admin'
        )
    );

-- ============================================
-- 4. CREATE FUNCTION TO VALIDATE FACE REGISTRATION
-- ============================================

CREATE OR REPLACE FUNCTION is_face_registered(user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    is_registered BOOLEAN;
BEGIN
    SELECT face_registered INTO is_registered
    FROM users
    WHERE id = user_uuid;
    
    RETURN COALESCE(is_registered, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. CREATE FUNCTION TO LOG FACE SCAN
-- ============================================

CREATE OR REPLACE FUNCTION log_face_scan(
    p_user_id UUID,
    p_scan_type TEXT,
    p_success BOOLEAN,
    p_similarity_score DECIMAL DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL,
    p_location_lat DECIMAL DEFAULT NULL,
    p_location_lng DECIMAL DEFAULT NULL,
    p_device_info JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO face_scan_logs (
        user_id,
        scan_type,
        success,
        similarity_score,
        error_message,
        location_lat,
        location_lng,
        device_info
    ) VALUES (
        p_user_id,
        p_scan_type,
        p_success,
        p_similarity_score,
        p_error_message,
        p_location_lat,
        p_location_lng,
        p_device_info
    )
    RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. CREATE FUNCTION TO UPDATE FACE EMBEDDINGS
-- ============================================

CREATE OR REPLACE FUNCTION update_face_embeddings(
    p_user_id UUID,
    p_embeddings JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE users
    SET 
        face_embeddings = p_embeddings,
        face_registered = TRUE,
        face_registered_at = NOW(),
        face_registration_count = face_registration_count + 1,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 7. CREATE VIEW FOR FACE REGISTRATION STATUS
-- ============================================

CREATE OR REPLACE VIEW user_face_status AS
SELECT 
    u.id,
    u.email,
    u.name,
    u.face_registered,
    u.face_registered_at,
    u.face_registration_count,
    COUNT(fsl.id) FILTER (WHERE fsl.scan_type = 'registration') as registration_attempts,
    COUNT(fsl.id) FILTER (WHERE fsl.scan_type = 'attendance') as attendance_scans,
    COUNT(fsl.id) FILTER (WHERE fsl.success = TRUE) as successful_scans,
    COUNT(fsl.id) FILTER (WHERE fsl.success = FALSE) as failed_scans,
    MAX(fsl.created_at) as last_scan_at
FROM users u
LEFT JOIN face_scan_logs fsl ON u.id = fsl.user_id
GROUP BY u.id, u.email, u.name, u.face_registered, u.face_registered_at, u.face_registration_count;

-- Grant access to the view
GRANT SELECT ON user_face_status TO authenticated;

-- ============================================
-- 8. ADD TRIGGER FOR FACE SCAN LOGS
-- ============================================

CREATE TRIGGER update_face_scan_logs_updated_at 
BEFORE UPDATE ON face_scan_logs
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 9. CREATE FUNCTION TO GET RECENT FAILED SCANS
-- ============================================

-- Security feature: detect suspicious activity
CREATE OR REPLACE FUNCTION get_recent_failed_scans(
    p_user_id UUID,
    p_minutes INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
    failed_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO failed_count
    FROM face_scan_logs
    WHERE user_id = p_user_id
    AND success = FALSE
    AND created_at > NOW() - (p_minutes || ' minutes')::INTERVAL;
    
    RETURN failed_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 10. UPDATE ATTENDANCE TABLE FOR FACE VERIFICATION
-- ============================================

-- Add face verification columns to attendance
ALTER TABLE attendance
ADD COLUMN IF NOT EXISTS face_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS face_similarity_score DECIMAL(5,4),
ADD COLUMN IF NOT EXISTS face_scan_log_id UUID REFERENCES face_scan_logs(id);

-- Add index
CREATE INDEX IF NOT EXISTS idx_attendance_face_verified ON attendance(face_verified);

-- Add comment
COMMENT ON COLUMN attendance.face_verified IS 'Indicates if attendance was verified using face recognition';
COMMENT ON COLUMN attendance.face_similarity_score IS 'Similarity score from face recognition (0.0000 to 1.0000)';

-- ============================================
-- 11. CREATE FUNCTION TO RECORD ATTENDANCE WITH FACE
-- ============================================

CREATE OR REPLACE FUNCTION record_attendance_with_face(
    p_user_id UUID,
    p_user_name TEXT,
    p_status TEXT,
    p_location TEXT,
    p_face_similarity_score DECIMAL,
    p_face_scan_log_id UUID,
    p_location_lat DECIMAL DEFAULT NULL,
    p_location_lng DECIMAL DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    attendance_id UUID;
BEGIN
    -- Check if face is registered
    IF NOT is_face_registered(p_user_id) THEN
        RAISE EXCEPTION 'User has not registered their face';
    END IF;
    
    -- Check if already checked in today
    IF EXISTS (
        SELECT 1 FROM attendance
        WHERE user_id = p_user_id
        AND DATE(check_in_time) = CURRENT_DATE
        AND check_out_time IS NULL
    ) THEN
        RAISE EXCEPTION 'User has already checked in today';
    END IF;
    
    -- Record attendance
    INSERT INTO attendance (
        user_id,
        user_name,
        check_in_time,
        status,
        location,
        face_verified,
        face_similarity_score,
        face_scan_log_id
    ) VALUES (
        p_user_id,
        p_user_name,
        NOW(),
        p_status,
        p_location,
        TRUE,
        p_face_similarity_score,
        p_face_scan_log_id
    )
    RETURNING id INTO attendance_id;
    
    RETURN attendance_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- MIGRATION COMPLETE!
-- ============================================
-- Next steps:
-- 1. Implement face recognition in Flutter app
-- 2. Test face registration flow
-- 3. Test attendance with face verification
-- 4. Monitor face_scan_logs for security issues
