CREATE OR REPLACE PROCEDURE IT.PRG_MOD_PRO_SUELDO(P_VALOR VARCHAR2)
 IS
-- PV 15-03-2013 
-- Proceso que verifica que los valores ingresados sean "O", "R" o "B"
-- Verifica que solo el usuario que tenga un rol asigando pueda cargar los valores "O" y "B" -Pagos OnLIne y Bacht
  v_tiene varchar2(1):=0;
BEGIN
  if ltrim(rtrim(p_valor)) not in ('R','B','O') then
    raise_application_error(-20002,'Valor incorrecto');
  else
    if ltrim(rtrim(p_valor)) <> 'R' then
      select count(1)
        into v_tiene
        from ba_usu_roles u
       where u.cod_usuario = user
         and u.cod_rol = fug_obt_pardinamico('ROL_MOD_PRO_SUELDO',null,null,null,null,null);

      if v_tiene = 0 then
        raise_application_error(-20002,'No tiene Rol para modificar');
      end if;
    end if;
  end if;
END;
/

