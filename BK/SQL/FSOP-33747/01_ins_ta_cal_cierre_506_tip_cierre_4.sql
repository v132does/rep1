Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1;End; 
/
insert into ta_cal_cierres (cod_ent_procesadora,
                            cod_modulo,
                            cod_modalidad,
                            ano,
                            mes,
                            fec_cierre,
                            fec_vencimiento,
                            usu_insercion,
                            fec_insercion,
                            usu_modificacion,
                            fec_modificacion,
                            cod_tip_cierre)
                     select 7,
                            cod_modulo,
                            506,
                            ano,
                            mes,
                            fec_cierre,
                            fec_vencimiento,
                            usu_insercion,
                            fec_insercion,
                            usu_modificacion,
                            fec_modificacion,
                            4
  from ta_cal_cierres t
 where t.cod_ent_procesadora = 1175
   and t.cod_modalidad = 53
   and t.cod_tip_cierre = 3
 order by ano, mes;
commit;
