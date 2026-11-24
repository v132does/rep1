CREATE OR REPLACE FUNCTION IT.FUG_OBT_NOM_CRC
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE,
  P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 )
 RETURN VARCHAR2
 IS

RESULT GE_PAR_GENERALES.DIR_CORREO%TYPE;
Begin
  SELECT NOMBRE
    INTO Result
    from BA_USUARIOS
    where cod_usuario = p_cod_usuario
    and dir_correo is not null
    and estado = 'A';
  return(Result);
   
   exception
      when no_data_found then
       BEGIN
       
       SELECT NOMBRE
        INTO Result
         from BA_USUARIOS
         where categoria='GS'
         and cod_oficina = p_cod_oficina
         and estado = 'A';
         return(Result); 
         
         exception
         when others then 
         return(null);
         end;
   END;
/

