CREATE OR REPLACE PROCEDURE IT.prc_gen_asi_aut_sobregiros
 IS
   /************************************************************/
   /*   Nombre: PRC_AJU_SOBREGIRO                               */
   /*   Hecho Por: Lic. Julio Cesar Leguizamon G.               */
   /*   Fecha: 15/12/2006                                       */
   /*   Objetivo: generar los asientos automaticos por los      */
   /*  ajustes de las lineas de sobregiro utilizadas que deben */
   /*  contabilizarse en cuentas de contingencia a fin de      */
   /*  registrar el riesgo                                     */
   /*  INVENTARIO CLINLISB                                     */
   /************************************************************/

rv_gcale               ge_calendarios%rowtype;
v_fcdehoy              date;
v_fcanter              ge_calendarios.fec_anterior%type;
v_nro_asiento          cb_asi_automaticos.nro_asiento%type;
v_nro_linea            ge_tip_asientos.nro_linea%type := 1;
v_cod_tip_asiento      ge_transacciones.cod_tip_asiento%type;
v_des_transaccion      ge_transacciones.descripcion%type;
v_cod_tip_asiento2     ge_transacciones.cod_tip_asiento2%type;
v_cod_moneda           ba_monedas.cod_moneda%type;
v_cod_sec_contable     ge_tip_asientos.cod_sec_contable%type;
v_residente            ge_clientes.residente%type;
v_mto_mon_rubro        ge_movimientos.monto%type;
v_cod_mon_local        ba_monedas.cod_moneda%type;
v_mto_mon_local        ge_movimientos.monto%type;
v_cod_rubro            cb_asi_automaticos_det_tmp.cod_rubro%type;
v_redondeo_ml          number(5);
v_hor_ini              varchar2(8);
v_hor_final            varchar2(8);

--Acumula por oficina, moneda, sector contable, residente, tip_deudor...todos
--los saldos de lineas sin utilizar
--modificaciones de BBVA 22/08/11 Juan José Estigarribia
--DESOPIMI-21 - OPTIMIZACION PRA_GEN_ASIENTOS - LCABRERA MARZO/2017
cursor sobregiros is
select cod_oficina, cod_moneda, cotizacion, cod_sec_contable, residente, cod_tip_deudor, sum(sal_linea) monto
  from (select c.cod_oficina, c.cod_moneda, decode(c.cod_moneda, pag_gen.fu_obt_mon_local,0,pag_gen.fu_obt_cotizacion(c.cod_moneda, v_fcdehoy)) cotizacion,
               tmp.cod_sec_contable, tmp.residente, tmp.cod_tip_deudor,
            case when sal_total < 0 then
              case when (abs(sal_total)+sal_retenido+sal_bloqueado) <= tmp.mto_linea then
                tmp.mto_linea - (abs(sal_total)+sal_retenido++sal_bloqueado)
              else
                0
              end
            else
              case when (sal_total-sal_retenido-sal_bloqueado) > 0 then
                tmp.mto_linea
              else
                case when abs(sal_total-sal_retenido-sal_bloqueado) > tmp.mto_linea then
                  0
                else
                  tmp.mto_linea - abs(sal_total-sal_retenido-sal_bloqueado)
                end
              end
            end sal_linea
        from cc_cta_corrientes c, cc_lin_sobregiros_tmp tmp
        where c.estado not in ('A','C','X')
        --and c.cod_ente is not null -- ICL 22/03/2012 Mail HB: Solo contabilizar Plan Nómina
        and c.nro_cuenta = tmp.nro_cuenta )
  group by cod_oficina, cod_moneda, cotizacion, cod_sec_contable, residente, cod_tip_deudor
  having sum(sal_linea) <> 0; -- 06-jun-2007 - para que no genere asientos con monto 0

cursor c_tip_asientos is
  select * from ge_tip_asientos
  where cod_tip_asiento in (v_cod_tip_asiento,v_cod_tip_asiento2) and
  cod_moneda = v_cod_moneda and
  (cod_sec_contable = v_cod_sec_contable or cod_sec_contable is null) and
  (ind_residente = v_residente or ind_residente = 'X');


procedure lp_ins_cc_lin_sobregiros_tmp is

PRAGMA AUTONOMOUS_TRANSACTION;

begin
  --Vaciar la tabla antes de comenzar el procesamiento
  Execute Immediate 'truncate table cc_lin_sobregiros_tmp';

  ---Actualización de datos para procesamiento de sobregiros actuales
  insert into cc_lin_sobregiros_tmp (nro_cuenta, cod_persona, cod_sec_contable, 
                                      residente, cod_tip_deudor, mto_linea)
    (SELECT c.nro_cuenta, g.cod_persona, g.cod_sec_contable, 
            g.residente, g.cod_tip_deudor, NVL(SUM(c.monto), 0) mto_linea
       FROM cc_lin_sobregiros c, ge_cta_clientes cta, ge_clientes g
      WHERE v_fcdehoy between c.fec_inicio and c.fec_vencimiento
        AND c.estado = 'A'
        and c.nro_cuenta is not null
        and c.nro_cuenta = cta.nro_cuenta
        and cta.relacion = 'P'
        and cta.cod_persona = g.cod_persona
      group by c.nro_cuenta, g.cod_persona, g.cod_sec_contable, 
               g.residente, g.cod_tip_deudor);
  commit;

  dbms_stats.gather_table_stats('IT','CC_LIN_SOBREGIROS_TMP');

end;

procedure lp_ins_rev_asientos is

v_nro_asiento cb_asi_automaticos.nro_asiento%type:= fug_obt_pardinamico('SIG_NRO_ASI_AUTOM_TMP');

begin
  
  ---Ejecución de Estadistica de Ejecución
  dbms_stats.gather_table_stats('IT','CB_ASI_AUTOMATICOS_DET_ANT');

  insert into cb_asi_automaticos_det_tmp
      (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
      tip_movimiento, mto_mon_rubro, mto_mon_local, descripcion, referencia,
      protegido, actualizado, val_cotizacion, distribuido, ref_movimiento,
      cod_modulo, cod_modalidad, cod_ofi_origen)

 select v_fcdehoy,
        cod_oficina,
        v_nro_asiento, 
        nro_linea + rownum,
        cod_rubro,
        decode(tip_movimiento, 'C', 'D', 'C') tip_movimiento,
        mto_mon_rubro,
        mto_mon_local,
        'Canc. Contingencia fecha ' || to_char(v_fcanter, 'dd/mm/yyyy') ||
        ' Oficina ' || cod_oficina descripcion,
        referencia,
        protegido,
        actualizado,
        val_cotizacion,
        distribuido,
        ref_movimiento,
        cod_modulo,
        cod_modalidad,
        cod_ofi_origen
   from cb_asi_automaticos_det_ant
  where fecha = v_fcanter
    and referencia = 'CONTI.LINEA'
    and descripcion not like '%Canc. Contingencia fecha%';


end;


/******************************************************************************/
--BLOQUE PRINCIPAL
/******************************************************************************/
BEGIN
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_fcanter := rv_gcale.fec_anterior;
  v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASI_AUTOM_TMP');

  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
  --DESOPIMI-21 - Optimización del proceso PRA_GEN_ASIENTOS - GENERACION DE ASIENTOS - DYD-SDSL-3368
  lp_ins_cc_lin_sobregiros_tmp;
  v_hor_final := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('PRC_AJU_SOBREGIROS_TMP','1-lp_ins_cc_lin_sobregiros_tmp', v_fcdehoy, v_hor_ini, v_hor_final);

   --Obtiene la Moneda Local
  v_cod_mon_local      := pag_gen.fu_obt_mon_local;

  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
  --Cancelar la contabilizacion de contingencia de la fecha anterior
  --lp_ins_rev_asientos;
  v_hor_final := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('PRC_AJU_SOBREGIROS_TMP','2-lp_ins_rev_asientos', v_fcdehoy, v_hor_ini, v_hor_final);

  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
  --Recuperar asiento relacionado a la transaccion
  begin
    select cod_tip_asiento, descripcion, cod_tip_asiento2
      into v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
      from ge_transacciones
     where cod_modulo = 4
       and cod_modalidad = 41
       and cod_transaccion = 920
       and cod_tip_asiento is not null;
  exception
  when no_data_found then
    raise_application_error(-20000,'Transaccion 41-920 no tiene asiento relacionado');
  when others then
    raise_application_error(-20001,'Error al recuperar asiento de ge_transacciones');
  end;
  v_hor_final := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prc_gen_asi_aut_sobregiros','3-consulta ge_transacciones', v_fcdehoy, v_hor_ini, v_hor_final);
  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
  
  --Contabilizar la contingencia de sobregiros del dia
  v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',4,41,v_cod_mon_local);
  for reg in sobregiros loop
    v_cod_sec_contable  := reg.cod_sec_contable;
    v_residente          := reg.residente;
    v_cod_moneda        := reg.cod_moneda;

    --Si la moneda es distinta a la moneda local se graba en mto_mon_rubro
    if v_cod_mon_local <> reg.cod_moneda then
      v_mto_mon_rubro := reg.monto;
      v_mto_mon_local := round((reg.monto * reg.cotizacion),v_redondeo_ml);
    else
      v_mto_mon_rubro := 0;
      v_mto_mon_local := reg.monto;
    end if;

    begin
      for reg2 in c_tip_asientos loop
        begin
          if reg2.ind_deudor = 'S' then
            v_cod_rubro := substr(reg2.cod_rubro,1,8)||ltrim(to_char(reg.cod_tip_deudor,'00'))||substr(reg2.cod_rubro,11,5);
          else
            v_cod_rubro := reg2.cod_rubro;
          end if;

          insert into cb_asi_automaticos_det_tmp
          (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
          tip_movimiento, mto_mon_rubro, mto_mon_local, descripcion, referencia,
          protegido, actualizado, val_cotizacion, distribuido, ref_movimiento,
          cod_modulo, cod_modalidad, cod_ofi_origen)
          values
          (v_fcdehoy, reg.cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rubro,
          reg2.tip_movimiento, v_mto_mon_rubro, v_mto_mon_local, 'Contingencia de sobregiros fecha '||to_char(v_fcdehoy,'dd/mm/yyyy')||' Oficina '||reg.cod_oficina, 'CONTI.LINEA',
          'N'/*reg.protegido*/, 'N'/*reg.actualizado*/, reg.cotizacion/*reg.val_cotizacion*/, 'N'/*reg.distribuido*/, null/*reg.ref_movimiento*/,
          4/*reg.cod_modulo*/, 41/*reg.cod_modalidad*/, 1/*reg.cod_ofi_origen*/);

          v_nro_linea := v_nro_linea + 1;
          exception
            when others then
            raise_application_error(-20000,'Error al insertar cb_asi_automaticos_det_tmp '||v_nro_linea||' '||sqlerrm);
        end;
      end loop;

    end;
  end loop;
  v_hor_final := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('prc_gen_asi_aut_sobregiros','4-sobregiros', v_fcdehoy, v_hor_ini, v_hor_final);

end;
/
