CREATE OR REPLACE PROCEDURE IT.pre_ver_sesiones IS
  CURSOR sesiones IS
    SELECT v.sid, v.serial# serial
      FROM ba_usuarios b, v$session v
     WHERE schemaname <> 'SYS'
       AND status <> 'KILLED'
       AND b.cod_usuario = username
       AND b.cod_usuario <> USER
       AND (v.program NOT LIKE '%JDBC%' AND v.OSUSER <> 'oracle') --Usuarios Servicios
       AND instr(fug_obt_pardinamico('USU_PRE_VER_SES'),',' || b.cod_usuario || ',') = 0;
BEGIN
  FOR reg IN sesiones LOOP
    it.pre_mat_sesion(reg.sid, reg.serial);
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Error en PRE_VER_SESIONES ' || SQLERRM);
END;
/
