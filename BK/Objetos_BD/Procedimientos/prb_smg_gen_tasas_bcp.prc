CREATE OR REPLACE PROCEDURE IT.PRB_SMG_GEN_TASAS_BCP IS
--variales de fecha--
v_ano_mes_anterior varchar2(6) := to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'yyyymm');
v_fec_actual ge_cuentas.fec_apertura%type := pag_cal.FU_OBT_FEC_ACTUAL(1);

CURSOR LEE_NRO_CTA IS 
select nro_cuenta,ss.semana,ss.desde,ss.hasta
  from mi_sb_tas_ape_semanales s
  inner join sb_semanas ss on ss.semana = s.corcod
 where substr(ss.semana,0,6)= v_ano_mes_anterior
 ;

Begin
  EXECUTE IMMEDIATE ('truncate table tas_real_mensual');
  
     for i in LEE_NRO_CTA loop  
        
        -- cajas de ahorro y ctas corrientes
        insert into TAS_REAL_MENSUAL
        select gc.nro_cuenta,gc.cod_modulo,gc.cod_modalidad,gc.fec_apertura,
                v_fec_actual, v_fec_actual-gc.fec_apertura cant_dias,
               i.semana,i.desde,i.hasta
          from ge_cuentas gc
         where gc.cod_modulo in ('3','4') and gc.cod_modalidad in ('31','41')
           and i.nro_cuenta=gc.nro_cuenta;
       
        -- CDA y Plazo Fijo
        insert into TAS_REAL_MENSUAL
        select gc.nro_cuenta,gc.cod_modulo,gc.cod_modalidad,gc.fec_apertura,
                gc.fec_vencimiento, gc.fec_vencimiento-gc.fec_apertura cant_dias,
               i.semana,i.desde,i.hasta
          from ge_cuentas gc
         where gc.cod_modulo in ('3') and gc.cod_modalidad in ( '33', '37','38' )
           and i.nro_cuenta=gc.nro_cuenta;
       
        -- TC y Prestamos
        insert into TAS_REAL_MENSUAL
        select gc.nro_cuenta,gc.cod_modulo,gc.cod_modalidad,gc.fec_apertura,
               gc.fec_vencimiento, pc.fec_vencimiento-pc.fec_inicio cant_dias,
               i.semana,i.desde,i.hasta
          from ge_cuentas gc, pr_cta_prestamos pc
         where gc.cod_modulo in ('5','6')
           and pc.nro_cuenta=gc.nro_cuenta
           and i.nro_cuenta=gc.nro_cuenta;
     end loop;

end PRB_SMG_GEN_TASAS_BCP;
/

