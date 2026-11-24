CREATE OR REPLACE PROCEDURE IT.TESTMAIL(fromm VARCHAR2,too VARCHAR2,sub VARCHAR2,body VARCHAR2,port NUMBER)
IS
objConnection UTL_SMTP.CONNECTION;
vrData VARCHAR2(32000);
BEGIN
objConnection := UTL_SMTP.OPEN_CONNECTION('172.20.20.111',25);
UTL_SMTP.HELO(objConnection, '172.20.20.111');
UTL_SMTP.MAIL(objConnection, fromm);
UTL_SMTP.RCPT(objConnection, too);
UTL_SMTP.OPEN_DATA(objConnection);

UTL_SMTP.WRITE_DATA(objConnection, 'From: '||fromm || UTL_TCP.CRLF);
UTL_SMTP.WRITE_DATA(objConnection, 'To: '||too || UTL_TCP.CRLF);

UTL_SMTP.WRITE_DATA(objConnection, 'Subject: ' || sub || UTL_tcp.CRLF);
UTL_SMTP.WRITE_DATA(objConnection, 'MIME-Version: ' || '1.0' || UTL_tcp.CRLF);
UTL_SMTP.WRITE_DATA(objConnection, 'Content-Type: ' || 'text/html;');

UTL_SMTP.WRITE_DATA(objConnection, 'Content-Transfer-Encoding: ' || '"8Bit"' || UTL_TCP.CRLF);
UTL_SMTP.WRITE_DATA(objConnection,UTL_TCP.CRLF);
UTL_SMTP.WRITE_DATA(objConnection,UTL_TCP.CRLF||'<HTML>');
UTL_SMTP.WRITE_DATA(objConnection,UTL_TCP.CRLF||'<BODY>');
UTL_SMTP.WRITE_DATA(objConnection,UTL_TCP.CRLF||'<FONT COLOR="red" FACE="Courier New">'||body||'</FONT>');
UTL_SMTP.WRITE_DATA(objConnection,UTL_TCP.CRLF||'</BODY>');
UTL_SMTP.WRITE_DATA(objConnection,UTL_TCP.CRLF||'</HTML>');
UTL_SMTP.CLOSE_DATA(objConnection);
UTL_SMTP.QUIT(objConnection);
EXCEPTION
WHEN UTL_SMTP.TRANSIENT_ERROR OR UTL_SMTP.PERMANENT_ERROR THEN
UTL_SMTP.QUIT(objConnection);
DBMS_OUTPUT.PUT_LINE(SQLERRM);
WHEN OTHERS THEN
UTL_SMTP.QUIT(objconnection);
DBMS_OUTPUT.PUT_LINE(SQLERRM);
END TESTMAIL;
/

