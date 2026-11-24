CREATE OR REPLACE PACKAGE BODY IT.PA_FILE_FTP IS

-- Retrieve an ASCII file from a remote FTP server.
FUNCTION fu_get_ascii (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2 IS

  v_conn    UTL_TCP.connection;
  v_return  VARCHAR2(4000);

BEGIN

  v_conn := utl_ftp.login(p_ip, p_port, p_user, p_pass);
  utl_ftp.ascii(p_conn => v_conn);
  utl_ftp.get(p_conn      => v_conn,
          p_from_file => p_fileorig,
          p_to_dir    => p_dir,
          p_to_file   => p_filedest);
  utl_ftp.logout(v_conn);
  utl_tcp.close_connection(v_conn);
  v_return := 'OK';

  RETURN v_return;

EXCEPTION
  WHEN OTHERS THEN
    UTL_FTP.LOGOUT(v_conn);
    UTL_TCP.close_connection(v_conn);
    RETURN SUBSTR(SQLERRM,1,4000);
    RAISE;
END;

-- Send an ASCII file to a remote FTP server.
FUNCTION fu_put_ascii (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2 IS

  v_conn    UTL_TCP.connection;
  v_return  VARCHAR2(4000);

BEGIN

  v_conn := utl_ftp.login(p_ip, p_port, p_user, p_pass);
  utl_ftp.ascii(p_conn => v_conn);
  utl_ftp.put(p_conn      => v_conn,
          p_from_dir  => p_dir,
          p_from_file => p_fileorig,
          p_to_file   => p_filedest);
  utl_ftp.logout(v_conn);
  utl_tcp.close_all_connections;

  v_return := 'OK';

  RETURN v_return;

EXCEPTION
  WHEN OTHERS THEN    
    UTL_FTP.LOGOUT(v_conn);
    UTL_TCP.close_connection(v_conn);
    RETURN SUBSTR(SQLERRM,1,4000);
    RAISE;
END;


-- Retrieve a binary file from a remote FTP server.
FUNCTION fu_get_binary (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2 IS

  v_conn    UTL_TCP.connection;
  v_return  VARCHAR2(4000);

BEGIN

  v_conn := utl_ftp.login(p_ip, p_port, p_user, p_pass);
  utl_ftp.binary(p_conn => v_conn);
  utl_ftp.get(p_conn      => v_conn,
          p_from_file => p_fileorig,
          p_to_dir    => p_dir,
          p_to_file   => p_filedest);
  utl_ftp.logout(v_conn);
  utl_tcp.close_connection(v_conn);

  v_return := 'OK';

  RETURN v_return;

EXCEPTION
  WHEN OTHERS THEN
    UTL_FTP.LOGOUT(V_CONN);
    UTL_TCP.close_connection(v_conn);
    RETURN SUBSTR(SQLERRM,1,4000);
    RAISE;
END;


-- Send a binary file to a remote FTP server.
FUNCTION fu_put_binary (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2 IS

  v_conn    UTL_TCP.connection;
  v_return  VARCHAR2(4000);

BEGIN

  v_conn := utl_ftp.login(p_ip, p_port, p_user, p_pass);
  utl_ftp.binary(p_conn => v_conn);
  utl_ftp.put(p_conn      => v_conn,
          p_from_dir  => p_dir,
          p_from_file => p_fileorig,
          p_to_file   => p_filedest);
  utl_ftp.logout(v_conn);
  
  v_return := 'OK';

  RETURN v_return;

EXCEPTION
  WHEN OTHERS THEN
    UTL_FTP.LOGOUT(v_conn);
    UTL_TCP.close_connection(v_conn);    
    RETURN SUBSTR(SQLERRM,1,4000);
    RAISE;
END;


END pa_file_ftp;
/
