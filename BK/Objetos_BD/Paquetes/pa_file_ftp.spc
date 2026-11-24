CREATE OR REPLACE PACKAGE IT.pa_file_ftp IS

  -- Author  : RICARDO BARRIOS - IDTKNOLOGY
  -- Created : 19/05/2011 03:28:40 PM
  -- Purpose : Recepcion o envio de archivos a traves de un servidor FTP
  
FUNCTION fu_get_ascii (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2;
  
FUNCTION fu_put_ascii (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2;
  
FUNCTION fu_get_binary (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2;
  
FUNCTION fu_put_binary (p_ip       IN VARCHAR2,
                    p_port     IN VARCHAR2 DEFAULT '21',
                    p_user     IN VARCHAR2,
                    p_pass     IN VARCHAR2,
                    p_dir      IN VARCHAR2,
                    p_fileorig IN VARCHAR2,
                    p_filedest IN VARCHAR2)
  RETURN VARCHAR2;      

END pa_file_ftp;
/

