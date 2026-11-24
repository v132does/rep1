CREATE OR REPLACE FUNCTION IT.FUG_OBT_DIR_MAIL_CRC
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE,
  P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
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
    exception
    when no_data_found then
    
     BEGIN
     SELECT DIR_CORREO
      INTO Result
       from BA_USUARIOS
       where categoria='GS'
       and cod_oficina = p_cod_oficina;
       return(Result); 
        exception
         when no_data_found then 
         return(null);
        end; 
     END;
/

