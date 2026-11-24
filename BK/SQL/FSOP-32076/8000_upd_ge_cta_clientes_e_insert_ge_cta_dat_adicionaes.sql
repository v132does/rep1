declare
  cursor c_cta_upd is
    SELECT a.nro_cuenta, s.cod_persona, p.nro_cuenta
      FROM ge_cta_clientes a, pr_cta_prestamos p, pr_solicitudes s
     where a.cod_persona = '9582852'
       AND a.cod_modalidad IN (971, 970)
       AND a.cod_modulo = p.COD_MODULO
       AND a.cod_modalidad = p.COD_MODALIDAD
       AND a.NRO_CUENTA = p.nro_cuenta
          /*AND p.COD_MODULO = S.cod_modulo
          AND p.cod_modalidad = s.COD_MODALIDAD */
       AND trim(p.NRO_solicitud) = trim(s.NRO_SOLICITUD);
begin
  BEGIN pre_ini_aplicacion; END; 
  FOR a IN c_cta_upd LOOP
    UPDATE ge_cta_clientes g
      SET g.cod_persona = a.cod_persona
    WHERE g.nro_cuenta = a.nro_cuenta
      AND g.cod_modalidad in (971, 970)
      AND g.cod_modulo = 6
      AND g.cod_persona = '9582852';
      --
      commit;
      insert into ge_cta_dat_adicionales(nro_cuenta,
                                         parametro,
                                         val_parametro)
                                   values(a.nro_cuenta,
                                          'IND_NO_MOS_CTA_APP',
                                          'S');
      commit;                                           
  END LOOP;
end;
