CREATE OR REPLACE FUNCTION IT.FUG_OBT_DIR_MAIL_USU
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 RETURN VARCHAR2
 IS

RESULT GE_PAR_GENERALES.DIR_CORREO%TYPE;
Begin
  SELECT DIR_CORREO
    INTO Result
    from BA_USUARIOS
    where cod_usuario = p_cod_usuario;
  return(Result);
Exception
  when others then
     return null;
End;
/

