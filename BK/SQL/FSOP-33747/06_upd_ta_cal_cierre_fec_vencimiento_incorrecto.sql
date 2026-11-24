Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1;End;
/
update ta_cal_cierres a
   set a.fec_vencimiento = (select t.fec_vencimiento from ta_cal_cierres t
                             where t.COD_ENT_PROCESADORA = a.cod_ent_procesadora
                               and t.COD_MODULO = 5
                               and t.COD_MODALIDAD = 506
                               and t.ANO = 2024
                               and t.MES = a.mes 
                               and t.COD_TIP_CIERRE = 4)
 where a.cod_ent_procesadora = 7
   and to_number(to_char(a.fec_vencimiento,'yyyymm')) <> to_char(a.ano) || lpad(to_char(a.mes),2,'0')
   and a.cod_tip_cierre in (1,2,3)
   and a.ano = 2024;
commit;
