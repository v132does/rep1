DECLARE
v_err varchar2(1000);
BEGIN
--Desabilitar los triggers
   sql_util.ejecute_dml('alter table PR_LIB_CUENTAS disable all triggers', v_err);
   IF v_err IS NOT NULL THEN
      raise_application_error(-20000, 'Al desabilitar triggers PR_LIB_CUENTAS ' || v_err);
   END IF;
BEGIN pre_ini_aplicacion; END; 
INSERT INTO PR_LIB_CUENTAS  (cod_banco, 
                              nro_cuenta, 
                              denominacion, 
                              cod_moneda, 
                              tip_chequera, 
                              sal_promedio,
                              fec_ingreso, 
                              usu_insercion, 
                              fec_insercion, 
                              usu_modificacion, 
                              fec_modificacion)
                       
                        SELECT cod_banco, 
                              nro_cuenta, 
                              denominacion, 
                              cod_moneda, 
                              tip_chequera, 
                              sal_promedio,
                              fec_ingreso,
                                  'MIGRA',
                                   SYSDATE,
                                   'MIGRA',
                                   SYSDATE
    FROM PR_LIB_CUENTAS@UENODESG A
    WHERE not exists(select 1 from PR_LIB_CUENTAS g 
                     where g.cod_banco = a.cod_banco
                     and   g.nro_cuenta = a.nro_cuenta);
    commit;
      sql_util.ejecute_dml('alter table PR_LIB_CUENTAS ENABLE all triggers', v_err);
   IF v_err IS NOT NULL THEN
      raise_application_error(-20000, 'Al habilitar triggers PR_LIB_CUENTAS ' || v_err);
   END IF;
end;
