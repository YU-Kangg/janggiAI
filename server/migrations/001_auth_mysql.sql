CREATE TABLE IF NOT EXISTS members (
  id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  email VARCHAR(254) NOT NULL,
  display_name VARCHAR(20) NOT NULL,
  role VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'user',
  password_algorithm VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  password_salt CHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  password_hash CHAR(44) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_at DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_members_email (email),
  CONSTRAINT chk_members_role CHECK (role IN ('user'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS auth_sessions (
  token_hash CHAR(43) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  member_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  created_at DATETIME(3) NOT NULL,
  PRIMARY KEY (token_hash),
  KEY ix_auth_sessions_member (member_id),
  KEY ix_auth_sessions_expires (expires_at),
  CONSTRAINT fk_auth_sessions_member FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
