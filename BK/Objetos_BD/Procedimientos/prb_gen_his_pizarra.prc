CREATE OR REPLACE PROCEDURE IT.prb_gen_his_pizarra IS
BEGIN
   IF pag_gen.fu_obt_cod_entidad != '9999' THEN
      EXECUTE IMMEDIATE 'truncate table cr_piz_plazos_his';
      insert into cr_piz_plazos_his SELECT cod_modulo,
       cod_modalidad,
       cod_moneda,
       mto_desde,
       plz_desde,
       plz_hasta,
       tas_interes,
       tas_minima,
       tas_maxima,
       usu_insercion,
       fec_insercion,
       usu_modificacion,
       fec_modificacion,
       tip_capitalizacion,
       tas_efectiva,
       cod_sub_modalidad,
       TO_NUMBER(to_char(pag_cal.fu_obt_fec_actual(1),'YYYY')),
       TO_NUMBER(to_char(pag_cal.fu_obt_fec_actual(1),'mm'))
  FROM cr_piz_plazos
 WHERE cod_modalidad IN (31, 33);
      COMMIT;
   END IF;
END prb_gen_his_pizarra;
/
