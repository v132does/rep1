CREATE OR REPLACE FUNCTION IT.FUO_OBT_ENT_USUARIO

 (VCODUSUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 )
 RETURN NUMBER
 IS
vcod_ente ge_ent_usuarios.cod_ente%type;
begin
    select cod_ente into vcod_ente
    from ge_ent_usuarios
    where cod_usuario = vcodusuario;

    return vcod_ente;
exception
   when no_data_found then
      raise_Application_error(-20001,'Usuario no tiene entidad asociada. '||sqlerrm);
   when others then
      raise_Application_error(-20002,'Obt.Ente. '||sqlerrm);
end;
/

