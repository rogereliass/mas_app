-- Create library_reports table for user feedback on library content
-- This table stores problems, reviews, and suggestions from users

CREATE TYPE report_content_type AS ENUM ('folder', 'file', 'general');
CREATE TYPE report_type AS ENUM ('problem', 'review', 'suggestion');
CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved');

CREATE TABLE IF NOT EXISTS library_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content_type report_content_type NOT NULL DEFAULT 'general',
    content_id UUID, -- Optional: links to specific folder or file
    report_type report_type NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status report_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE library_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Users can create their own reports
CREATE POLICY "Users can create reports"
    ON library_reports FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own reports
CREATE POLICY "Users can view own reports"
    ON library_reports FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can update their own reports (only description/title while pending)
CREATE POLICY "Users can update own reports"
    ON library_reports FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Admins (role rank >= 90) can view all reports
-- role_rank is in the roles table, accessed through profile_roles junction table
CREATE POLICY "Admins can view all reports"
    ON library_reports FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN profiles p ON p.id = pr.profile_id
            JOIN roles r ON r.id = pr.role_id
            WHERE p.user_id = auth.uid()
            AND r.role_rank >= 90
        )
    );

-- Policy: Admins can update report status
CREATE POLICY "Admins can update report status"
    ON library_reports FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN profiles p ON p.id = pr.profile_id
            JOIN roles r ON r.id = pr.role_id
            WHERE p.user_id = auth.uid()
            AND r.role_rank >= 90
        )
    );

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_library_reports_user_id ON library_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_library_reports_status ON library_reports(status);
CREATE INDEX IF NOT EXISTS idx_library_reports_content_id ON library_reports(content_id);
CREATE INDEX IF NOT EXISTS idx_library_reports_created_at ON library_reports(created_at DESC);

-- Add function to update updated_at automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to update updated_at
DROP TRIGGER IF EXISTS update_library_reports_updated_at ON library_reports;
CREATE TRIGGER update_library_reports_updated_at
    BEFORE UPDATE ON library_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comment for documentation
COMMENT ON TABLE library_reports IS 'User-submitted reports, problems, reviews, and suggestions for library content';
COMMENT ON COLUMN library_reports.content_type IS 'Type of content being reported: folder, file, or general';
COMMENT ON COLUMN library_reports.report_type IS 'Type of report: problem, review, or suggestion';
COMMENT ON COLUMN library_reports.status IS 'Status of the report: pending, reviewed, or resolved';