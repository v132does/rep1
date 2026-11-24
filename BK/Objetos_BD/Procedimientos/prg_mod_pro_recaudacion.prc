CREATE OR REPLACE PROCEDURE IT.PRG_MOD_PRO_RECAUDACION (P_VALOR VARCHAR2)
 IS
-- Proceso que verifica que los valores ingresados sean "O", o "B"
-- Verifica que solo el usuario que tenga un rol asigando pueda cargar los valores "O" y "B" -Pagos OnLIne y Bacht
  v_tiene varchar2(1):=0;
BEGIN
  if ltrim(rtrim(p_valor)) not in ('B','O') then
    raise_application_error(-20002,'Valor incorrecto');
  else
    if ltrim(rtrim(p_valor)) <> 'R' then
       if NVL(fug_obt_per_programa(USER, fug_obt_pardinamico('COD_PRO_CON_RECAUDACION'), 'U'),'N') = 'N' then
          raise_application_error(-20002,'Rol no tiene permiso para modificar');
       end if;
    end if;
  end if;
END;
/

