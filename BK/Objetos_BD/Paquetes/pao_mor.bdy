CREATE OR REPLACE PACKAGE BODY IT.PAO_MOR IS
/* Guarda los sucesos de los procesos de Informconf */
/* modificado */
v_exi_error varchar2(1);--Variable para verificar si se ha generado el archivo de informconf en el día -- JIRA DYDMR-1594 --vamarilla-- feb/2015
v_hora_generado date;

PROCEDURE PR_INS_INFORME
 (P_PROCESO IN CO_INF_PROCESOS.NOM_PROCESO%TYPE
 ,P_FEC_INI IN DATE
 ,P_COMENTARIO IN CO_INF_PROCESOS.COMENTARIO%TYPE
 ,P_ERROR IN BOOLEAN DEFAULT TRUE
 ) 
 IS
  v_error      CO_INF_PROCESOS.ERROR%TYPE;
  v_mensaje    CO_INF_PROCESOS.MENSAJE%TYPE;
  v_archivo    UTL_FILE.FILE_TYPE;
  v_nom_ascii   varchar2(16);
  v_buffer     VARCHAR2(3000);
 
PRAGMA AUTONOMOUS_TRANSACTION;
  
BEGIN
  IF p_error THEN
    v_error   := sqlcode;
    v_mensaje := sqlerrm;
  END IF;
  ---DYDMR-10135 Incidencia SAU - ITGF - Optimización Proceso Informconf
  /*IF v_directorio IS NOT NULL THEN
    BEGIN
      if utl_file.is_open(v_archivo) then
        utl_file.fclose(v_archivo);
      end if;
      v_nom_ascii := 'log_' || to_char( p_fec_ini, 'YYYYMMDD' ) || '.txt';
      v_archivo   := utl_file.fopen(v_directorio,v_nom_ascii,'w');
      v_buffer := rpad( p_proceso, 30, ' ' ) || ' ' ||
                  to_char( p_fec_ini, 'DD/MM/YYYY HH24:MI:SS' ) || ' ' ||
                  to_char( sysdate, 'DD/MM/YYYY HH24:MI:SS' ) || ' ' ||
                  lpad( to_char( nvl( v_error, 0 ) ), 6, ' ' ) || ' ' ||
                  rpad( nvl( v_mensaje, ' ' ), 300, ' ' ) || ' ' ||
                  p_comentario;
      utl_file.put_line(v_archivo, v_buffer);
      utl_file.fclose(v_archivo);
    EXCEPTION
      when others then
        RAISE_APPLICATION_ERROR( -20112, 'ERROR AL ESCRIBIR LOG ' || sqlerrm );
    END;
  END IF;*/
 /*CROIOSI-1: Inclusión de Operaciones Vencidas y Sobregiros en la base de Informconf*/
 /*ITC-LCABRERA 08/2014 */
 /*Se agrega tratamiento de Excepciones necesarias identificadas en pruebas*/

 begin
  insert into co_inf_procesos( nom_proceso,
                               fec_ini,
                               fec_fin,
                               error,
                               mensaje,
                               comentario )
                       values( p_proceso,
                               p_fec_ini,
                               sysdate,
                               v_error,
                               v_mensaje,
                               p_comentario );
 COMMIT;
 exception
   when others then
      RAISE_APPLICATION_ERROR( -20001, 'ERROR. al insertar en tabla co_inf_procesos' || sqlerrm );
 end;
EXCEPTION
  when others then
    RAISE_APPLICATION_ERROR( -20001, 'ERROR. en Proceso PR_INS_INFORME' || sqlerrm );
END PR_INS_INFORME;
FUNCTION lf_obt_dato(p_dato in varchar2) return varchar2 is
     v_result varchar(500):= '';
  BEGIN
     select replace(p_dato,chr(9),'') into v_result from dual;
     return v_result;
   EXCEPTION
   WHEN OTHERS THEN
      RETURN 'ERROR';
END;
/* Obtiene el código de operación Informconf a partir de la cuenta */
FUNCTION FU_OBT_INF_OPERACION
 (P_COD_MODULO IN NUMBER
 ,P_RELACION IN VARCHAR2
 ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
 )
 RETURN NUMBER
 IS
  V_FEC_INI DATE := sysdate;
  V_OPERACION CO_INF_OPERACIONES.COD_INF_OPERACION%TYPE;
BEGIN
  select cod_inf_operacion
    into v_operacion
    from co_inf_ope_relaciones
   where relacion = p_relacion
     and cod_modulo = p_cod_modulo
     --and nvl(cod_modalidad,0) = decode(p_cod_modulo,15,p_cod_modalidad,0); --FSOP-42050 
     ;
  ----
  return v_operacion;
EXCEPTION
  when others then
    pao_mor.pr_ins_informe( 'FUNCION F_obt_inf_operacion',
                            v_fec_ini,
                            'Error al buscar la operación de informconf, Módulo ' || to_char( p_cod_modulo ) ||
                            ' Relación ' || p_relacion );
    return v_operacion;
END FU_OBT_INF_OPERACION;
/* Obtiene la moneda Informconf para la moneda del sistema */
FUNCTION FU_OBT_INF_MONEDA
 (P_COD_MONEDA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
  v_cod_inf CO_INF_MONEDAS.COD_INF_MONEDA%TYPE;
  v_fec_ini DATE := sysdate;
BEGIN
  select cod_inf_moneda
    into v_cod_inf
    from co_inf_monedas
   where cod_moneda = p_cod_moneda;
  return v_cod_inf;
EXCEPTION
  when others then
    v_cod_inf := 1;
    pao_mor.pr_ins_informe( 'FUNCION F_OBT_MON_INFORMCONF',
                            v_fec_ini,
                            'Error al buscar código de moneda para Informconf ' || p_cod_moneda );
    return v_cod_inf;
END FU_OBT_INF_MONEDA;
/* Proceso de generación de datos para Informconf */
PROCEDURE PR_PRO_INF_DIARIO( P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6) ) ) IS
  /*
  || EFECTUA      : Proceso encargado de generar la información diaria de inclusión/exclusión
  ||                de clientes en Informconf en la tabla CO_INF_OPE_DIARIAS.
  || DEPENDENCIAS : Parámetros: * CAN_ANO_PRESCRIPCION
  ||                            * DIA_MOR_INI_INFORMCONF
  ||                            * DIA_MOR_FIN_INFORMCONF
  ||                            * INC_ASO_INFORMCONF
  || HISTORIA     : 10/08/2005 | PPalella     | Definición y elaboración inicial
  ||                30/12/2005 | PPalella     | Controles para Prescripción de cuentas
  ||                           |              |
  */
  c_mes_tar_presc      CONSTANT VARCHAR2(20)                 := fug_obt_pardinamico( 'CAN_MES_PRESCRIPCION', 5 );
  c_mes_pre_presc      CONSTANT VARCHAR2(20)                 := fug_obt_pardinamico( 'CAN_MES_PRESCRIPCION', 6 );
  c_mes_ope_ven_presc  CONSTANT VARCHAR2(20)                 := fug_obt_pardinamico( 'CAN_MES_PRESCRIPCION', 15 );
  c_fec_tarjeta        CONSTANT DATE                         := pag_cal.fu_obt_fec_actual(5);
  c_fec_prestamo       CONSTANT DATE                         := pag_cal.fu_obt_fec_actual(6);
  c_fec_ope_vencida    CONSTANT DATE                         := pag_cal.fu_obt_fec_actual(15);
  c_fec_actual         CONSTANT DATE                         := trunc( pag_cal.fu_obt_fec_actual(12) ); -- Fecha del módulo de Cobranzas
  c_nom_proceso        CONSTANT VARCHAR2(30)                 := 'PR_PRO_INF_DIARIO';
  v_reg                CO_INF_OPE_DIARIAS%ROWTYPE;
  v_men_error          CO_INF_PROCESOS.COMENTARIO%TYPE;
  v_dia_atr_ini        NUMBER                                := fug_obt_pardinamico( 'DIA_MOR_INI_INFORMCONF' );
  v_dia_atr_fin        NUMBER                                := fug_obt_pardinamico( 'DIA_MOR_FIN_INFORMCONF' );
  v_mto_min_mon_local  CO_INF_OPE_DIARIAS.TOT_OPERACION%type := fug_obt_pardinamico( 'MTO_MIN_MON_LOCAL' );
  v_mto_min_mon_fuerte CO_INF_OPE_DIARIAS.TOT_OPERACION%type := fug_obt_pardinamico( 'MTO_MIN_MON_FUERTE' );
  c_fec_ini            CONSTANT DATE := sysdate;
  v_cli_informconf     VARCHAR2(1);
  v_cli_especial VARCHAR2(1);
  v_cli_confidencial varchar2(1);

  --
  v_con_errores     NUMBER := 0;
  /*v_cont_pendientes NUMBER;
  v_cont_generados  NUMBER;*/
  v_mensaje         VARCHAR2(2000);
  v_error           EXCEPTION;
  v_nro_registro    NUMBER(8);
  v_mon_local       ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_mon_fuerte      ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
--
  /*
  || Este cursor contendra informacion referente a los registros nuevos
  || que deberan ser informados.
  */
  CURSOR dat_insertar
      IS select fec_proceso, cod_persona, ide_operacion, cod_modulo, cod_modalidad, cod_moneda, relacion, fec_operacion,
                decode( cod_modulo, 15, fec_ven_pendiente,greatest( fec_ven_pendiente, nvl(fec_operacion,trunc(sysdate)))) fec_ven_pendiente, fec_ult_pago,
                decode( decode( pla_operacion, abs( pla_operacion ), pla_operacion, 0 ), 0, 1, pla_operacion ) pla_operacion,
                decode( cod_modulo, 5, greatest( sal_actual, tot_linea ), tot_operacion ) tot_operacion,
                sal_actual, fin_registro, estado
           from ( select trunc( p_fec_proceso ) fec_proceso, c.cod_persona,
                        p.nro_cuenta ide_operacion, p.cod_modulo, p.cod_modalidad, p.cod_moneda, c.relacion,
                        p.fec_inicio fec_operacion,
                        decode( nvl( p.dia_atraso, 0 ), 0, c_fec_prestamo,
                                                        c_fec_prestamo - nvl( p.dia_atraso, 0 ) ) fec_ven_pendiente,
                        nvl( max( s.fec_ult_pago ), p.fec_inicio ) fec_ult_pago,
                        round( months_between( ( c_fec_prestamo +
                                                 ( p.fec_vencimiento - p.fec_inicio ) ), c_fec_prestamo ), 0 ) pla_operacion,
                        sum( nvl( s.mto_capital, 0 ) + nvl( s.mto_interes, 0 ) + nvl( s.mto_int_documentado, 0 ) ) tot_operacion,
                        nvl( p.sal_cap_batch, 0 ) + nvl( p.sal_int_batch, 0 ) + nvl( p.sal_int_ade_batch, 0 ) sal_actual,
                        'I' fin_registro, 'P' estado, 0 tot_linea
                   from ge_est_cuentas e, pr_cuotas s, ge_cta_clientes c, pr_cta_prestamos p
                  where p.nro_cuenta = c.nro_cuenta
                    and p.dia_atraso between v_dia_atr_ini and v_dia_atr_fin
                    and p.nro_cuenta = s.nro_cuenta
                    and s.nro_cuota > 0
                    and p.cod_modulo = e.cod_modulo
                    and p.cod_modalidad = e.cod_modalidad
                    and p.estado = e.estado
                    and nvl( e.activo, 'N' ) = 'S'
                    --DYDMR-2589 ITGF - Inclusión a Base Adefi SC 22552, se agrega el nvl para el caso de cuentas que no tuvieron pago
                    --and nvl(s.fec_ult_pago, p.fec_inicio) < c_fec_actual -- SC 18101 hay que reportar situacion al cierre
                    ---DYDMR-5609 - Incidencia SAU - ITGF - Datos a Enviar - Informconf (nota: si se filtra por ultimo pago solo suma las cuotas pagadas)
                    and p.fec_inicio < c_fec_actual -- SC 18101 hay que reportar situacion al cierre
                    and NOT EXISTS( select x.cod_persona
                                      from co_inf_personas x
                                     where x.relacion = c.relacion
                                       and x.cod_moneda = p.cod_moneda
                                       and x.cod_modulo = p.cod_modulo
                                       and x.cod_persona = c.cod_persona
                                       and x.ide_operacion = c.nro_cuenta )
                    /*
                    || Esto es para que no inserte los registros de días
                    || anteriores, marcados como erróneos, ni tampoco los
                    || que están marcados como (G)enerados, pues estos ya
                    || fueron enviados a Informconf.
                    */
                    and NOT EXISTS( select y.cod_persona
                                      from co_inf_ope_diarias y
                                     where y.fec_proceso = c_fec_actual
                                       and y.cod_persona = c.cod_persona
                                       and y.fin_registro = 'I'
                                       /*and y.estado IN( 'E', 'G', 'P' )*/)
                    and EXISTS( select cod_moneda
                                  from co_inf_monedas
                                 where cod_moneda = p.cod_moneda )
                    and nvl( p.sal_cap_batch, 0 ) + nvl( p.sal_int_batch, 0 ) + nvl( p.sal_int_ade_batch, 0 ) >=
                     decode( p.cod_moneda, v_mon_local,  v_mto_min_mon_local,
                                           v_mon_fuerte, v_mto_min_mon_fuerte )
                    /*
                    || Esta parte es para verificar que no se vayan operaciones PRESCRIPTAS
                    */
                    and ( months_between( c_fec_prestamo,
                                          add_months( p.fec_inicio,
                                                      round( months_between( ( c_fec_prestamo +
                                                                               ( p.fec_vencimiento - p.fec_inicio ) ),
                                                                               c_fec_prestamo ), 0 ) ) ) ) < c_mes_pre_presc
                    /*
                    || Esta parte es que no envíe las cuentas con transacciones prohibídas
                    */
                    and NOT EXISTS( select 1
                                      from ge_tra_prohibidas z
                                     where z.cod_transaccion = 1011 -- No enviar a Informconf
                                       and z.cod_modulo = p.cod_modulo
                                       and z.cod_modalidad = p.cod_modalidad
                                       and z.nro_cuenta = p.nro_cuenta )
                    /*
                    || Esto se agregó para que no envíe los Bonos del tesoro y para Bríos que
                    || no envíe los bonos privados.
                    */
                  group by c.cod_persona, p.cod_modulo,p.cod_modalidad, p.cod_moneda, c.relacion, p.nro_cuenta,
                        decode( nvl( p.dia_atraso, 0 ), 0, c_fec_prestamo,
                                                           c_fec_prestamo - nvl( p.dia_atraso, 0 ) ), p.fec_inicio,
                        round( months_between( ( c_fec_prestamo + ( p.fec_vencimiento - p.fec_inicio ) ), c_fec_prestamo ), 0 ),
                        nvl( p.sal_cap_batch, 0 ) + nvl( p.sal_int_batch, 0 ) + nvl( p.sal_int_ade_batch, 0 ), 0
               UNION
                 select c_fec_actual fec_proceso, c.cod_persona, t.nro_cuenta ide_operacion,
                        t.cod_modulo, t.cod_modalidad, t.cod_moneda, c.relacion,
                      (select min(z.fec_emision)
                        FROM ta_tarjetas z
                        where z.nro_cuenta = t.nro_cuenta ) fec_operacion,
                        decode( nvl( t.dia_mora, 0 ), 0, c_fec_tarjeta,
                                                      c_fec_tarjeta - nvl( t.dia_mora, 0 )  ) fec_ven_pendiente,
                        nvl( max( t.fec_ult_pago ), t.fec_apertura ) fec_ult_pago,
                        round( months_between( ( c_fec_tarjeta + t.dia_mora ), c_fec_tarjeta ), 0 ) pla_operacion,
                        sum( nvl( t.sal_facturar, 0 ) + nvl( t.sal_facturado, 0 ) + nvl( t.sal_financiado, 0 ) + nvl( t.sal_cuo_pendientes, 0 ) ) tot_operacion,
                        sum( nvl( t.sal_facturar, 0 ) + nvl( t.sal_facturado, 0 ) + nvl( t.sal_financiado, 0 ) + nvl( t.sal_cuo_pendientes, 0 ) ) sal_actual,
                        'I' fin_registro, 'P' estado,
                        sum( nvl( t.lin_credito, 0 ) + nvl( t.lin_cuotas, 0 ) ) lin_credito
                   from ge_est_cuentas e, ge_cta_clientes c, ta_cta_tarjetas t
                  where t.nro_cuenta = c.nro_cuenta
                    and t.dia_mora between v_dia_atr_ini and v_dia_atr_fin
                    and NOT EXISTS( select x.cod_persona
                                      from co_inf_personas x
                                     where x.relacion = c.relacion
                                       and x.cod_moneda = t.cod_moneda
                                       and x.cod_modulo = t.cod_modulo
                                       and x.cod_persona = c.cod_persona
                                       and x.ide_operacion = c.nro_cuenta )
                    and c.relacion IN( 'P' )
                    and t.cod_modulo = e.cod_modulo
                    and t.cod_modalidad = e.cod_modalidad
                    and t.estado = e.estado
                    and nvl( e.activo, 'N' ) = 'S'
                    /*
                    || Esto es para que no inserte los registros de días
                    || anteriores, marcados como erróneos, ni tampoco los
                    || que están marcados como (G)enerados, pues estos ya
                    || fueron enviados a Informconf.
                    */
                    and NOT EXISTS( select y.cod_persona
                                      from co_inf_ope_diarias y
                                     where y.fec_proceso = c_fec_actual
                                       and y.cod_persona = c.cod_persona
                                       and y.fin_registro = 'I'
                                       /*and y.estado IN( 'E', 'G','P' )*/)
                    and EXISTS( select cod_moneda
                                  from co_inf_monedas
                                 where cod_moneda = t.cod_moneda )
                    /*
                    || Esta parte es para verificar que no se vayan operaciones PRESCRIPTAS
                    */
                    and round( months_between( c_fec_tarjeta, c_fec_tarjeta - t.dia_mora ) ) < c_mes_tar_presc
                    /*
                    || Esta parte es que no envíe las cuentas con transacciones prohibídas
                    */
                    and NOT EXISTS( select 1
                                      from ge_tra_prohibidas z
                                     where z.cod_transaccion = 1011 -- No enviar a Informconf
                                       and z.cod_modulo = t.cod_modulo
                                       and z.cod_modalidad = t.cod_modalidad
                                       and z.nro_cuenta = t.nro_cuenta )
                  group by c.cod_persona, t.cod_modulo,t.cod_modalidad, t.cod_moneda, c.relacion, t.nro_cuenta,
                        decode( nvl( t.dia_mora, 0 ), 0, c_fec_tarjeta, c_fec_tarjeta - nvl( t.dia_mora, 0 ) ), t.fec_apertura,
                        round( months_between( ( c_fec_tarjeta + t.dia_mora ), c_fec_tarjeta ), 0 )
                  having sum( nvl( t.sal_facturar, 0 ) + nvl( t.sal_facturado, 0 ) + nvl( t.sal_financiado, 0 ) + nvl( t.sal_cuo_pendientes, 0 ) ) >=
                            decode( t.cod_moneda, v_mon_local,  v_mto_min_mon_local,
                                                  v_mon_fuerte, v_mto_min_mon_fuerte )
           UNION
          /*Bloque de Consulta: Operaciones Vencidas: Modalidad 151-Tarjetas Venc y 152-Sobregiros*/
    /*CROIOSI-1: Inclusión de Operaciones Vencidas y Sobregiros en la base de Informconf*/
    /*ITC-LCABRERA 08/2014 */
          select c_fec_actual fec_proceso,
                 c.cod_persona,
                 v.nro_cuenta ide_operacion,
                 v.cod_modulo,
                 v.cod_modalidad,
                 v.cod_moneda,
                 c.relacion,
                 --v.fec_apertura fec_operacion,
                 decode(v.cod_modalidad, 151, t.fec_apertura, 152, l.fec_apertura,v.fec_apertura) fec_operacion,
                 v.fec_ini_mora fec_ven_pendiente,
                 nvl(v.fec_ult_movimiento, v.fec_apertura) fec_ult_pago,
                 round(months_between((c_fec_ope_vencida +(c_fec_ope_vencida - v.Fec_Apertura)),
                                      c_fec_ope_vencida),0) pla_operacion,
                 v.mto_origen tot_operacion,
                 v.sal_tot_batch sal_actual, -- SC 18101 hay que reportar situacion al cierre
                 'I' fin_registro,
                 'P' estado,
                 0 lin_credito
            from ge_est_cuentas e, ge_cta_clientes c, ov_cta_vencidas v, ge_par_dinamicos g,
                 ta_cta_tarjetas t, cc_cta_corrientes l
           where v.nro_cuenta = c.nro_cuenta
             and v.dia_atraso between v_dia_atr_ini and v_dia_atr_fin
             and NOT EXISTS (select x.cod_persona
                    from co_inf_personas x
                   where x.relacion = c.relacion
                     and x.cod_moneda = v.cod_moneda
                     and x.cod_modulo = v.cod_modulo
                     and x.cod_persona = c.cod_persona
                     and x.ide_operacion = c.nro_cuenta)
             and c.relacion IN ('P')
             and v.cod_modulo = e.cod_modulo
             and v.cod_modalidad = e.cod_modalidad
             and v.estado = e.estado
             and g.parametro = 'INF_MOD_OPE_VENCIDAS'
             and g.cod_modulo = v.cod_modulo
             and g.cod_modalidad = v.cod_modalidad
             and g.val_parametro = 'S'
             and nvl(e.activo, 'N') = 'S'
             and v.nro_cta_origen = t.nro_cuenta(+)
             and v.nro_cta_origen = l.nro_cuenta(+)
            /*
             || Esto es para que no inserte los registros de días
             || anteriores, marcados como erróneos, ni tampoco los
             || que están marcados como (G)enerados, pues estos ya
             || fueron enviados a Informconf.
             */
             and NOT EXISTS (select y.cod_persona
                    from co_inf_ope_diarias y
                   where y.fec_proceso = c_fec_actual
                     and y.cod_persona = c.cod_persona
                     and y.fin_registro = 'I'
                     /*and y.estado IN ('E', 'G', 'P')*/)
             and EXISTS
           (select cod_moneda
                    from co_inf_monedas
                   where cod_moneda = v.cod_moneda)
            /*
             || Esta parte es para verificar que no se vayan operaciones PRESCRIPTAS
             */
             and round(months_between(c_fec_ope_vencida, c_fec_ope_vencida - v.dia_atraso)) < c_mes_ope_ven_presc
            /*
            || Esta parte es que no envíe las cuentas con transacciones prohibídas
            */
             and NOT EXISTS
           (select 1
                    from ge_tra_prohibidas z
                   where z.cod_transaccion = 1011 -- No enviar a Informconf
                     and z.cod_modulo = v.cod_modulo
                     and z.cod_modalidad = v.cod_modalidad
                     and z.nro_cuenta = v.nro_cuenta));

  /*
  || Este cursor contendra informacion referente a los registros
  || que tengan variacion de saldos.
  */
  CURSOR dat_actualizar
      IS select cod_persona, cod_modulo, cod_modalidad, cod_moneda, relacion, mto_ope_anterior, mto_operacion, fec_operacion,
                ide_operacion, cod_oficina, dia_atraso, sal_anterior, activo, sal_actual, ind_variacion,
                decode( cod_modulo, 15, fec_ven_pendiente,greatest( fec_ven_pendiente, nvl(fec_operacion,trunc(sysdate)) )) fec_ven_pendiente,
                decode( decode( pla_operacion, abs( pla_operacion ), pla_operacion, 0 ), 0, 1, pla_operacion ) pla_operacion,
                nvl( fec_ult_pago, fec_operacion ) fec_ult_pago, tip_registro
           from ( select d.cod_persona, d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.relacion, mto_operacion mto_ope_anterior,
                         d.mto_operacion, d.fec_operacion, d.ide_operacion, p.cod_oficina, p.dia_atraso, d.saldo sal_anterior,
                         nvl( e.activo, 'N' ) activo,
                         ( nvl( p.sal_cap_batch, 0 ) + nvl( p.sal_int_batch, 0 ) + nvl( p.sal_int_ade_batch, 0 ) ) sal_actual,
                         decode( ( nvl( p.sal_cap_batch, 0 ) + nvl( p.sal_int_batch, 0 ) + nvl( p.sal_int_ade_batch, 0 ) ),
                                   nvl( d.saldo, 0 ), 'N', 'S' ) ind_variacion,
                         decode( nvl( p.dia_atraso, 0 ), 0, c_fec_prestamo,
                                                         c_fec_prestamo - nvl( p.dia_atraso, 0 ) ) fec_ven_pendiente,
                         round( months_between( ( c_fec_prestamo +
                                                  ( p.fec_vencimiento - p.fec_inicio ) ), c_fec_prestamo ), 0 ) pla_operacion,
                         max( o.fec_ult_pago ) fec_ult_pago, 'A' tip_registro
                    from co_inf_personas d, pr_cta_prestamos p, pr_cuotas o, ge_est_cuentas e, ge_cta_clientes l
                   where d.cod_persona = l.cod_persona
                     and d.ide_operacion = l.nro_cuenta
                     and d.relacion = l.relacion
                     and d.ide_operacion = p.nro_cuenta
                     and d.cod_modulo = p.cod_modulo
                     and d.cod_moneda = p.cod_moneda
                     and o.nro_cuenta = p.nro_cuenta
                     and o.nro_cuota > 0
                     and e.cod_modulo = p.cod_modulo
                     and e.cod_modalidad = p.cod_modalidad
                     and e.estado = p.estado
                     --DYDMR-2589 ITGF - Inclusión a Base Adefi SC 22552, se agrega el nvl para el caso de cuentas que no tuvieron pago
                     and nvl(o.fec_ult_pago, p.fec_inicio) < c_fec_actual -- SC 18101 hay que reportar situacion al cierre anterior al inicio de día
                     /*
                     || Esta parte es para verificar que no se vayan operaciones PRESCRIPTAS
                     */
                     and ( months_between( c_fec_prestamo,
                                           add_months( d.fec_operacion,
                                                       round( months_between( ( c_fec_prestamo +
                                                                                ( p.fec_vencimiento - p.fec_inicio ) ),
                                                                                c_fec_prestamo ), 0 ) ) ) ) < c_mes_pre_presc
                    /*
                    || Esta parte es que no envíe las cuentas con transacciones prohibídas
                    */
                    and NOT EXISTS( select 1
                                      from ge_tra_prohibidas z
                                     where z.cod_transaccion = 1011 -- No enviar a Informconf
                                       and z.cod_modulo = p.cod_modulo
                                       and z.cod_modalidad = p.cod_modalidad
                                       and z.nro_cuenta = p.nro_cuenta )
                    /*
                    || Esto se agregó para que no envíe los Bonos del tesoro y para Bríos que
                    || no envíe los bonos privados.
                    */
                   group by d.cod_persona, d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.relacion, d.mto_operacion, d.fec_operacion,
                         d.ide_operacion, p.cod_oficina, p.dia_atraso, d.saldo, nvl( e.activo, 'N' ),
                         ( nvl( p.sal_cap_batch, 0 ) + nvl( p.sal_int_batch, 0 ) + nvl( p.sal_int_ade_batch, 0 ) ),
                         decode( ( nvl( p.sal_cap_batch, 0 ) + nvl( p.sal_int_batch, 0 ) + nvl( p.sal_int_ade_batch, 0 ) ),
                                   nvl( d.saldo, 0 ), 'N', 'S' ),
                         decode( nvl( p.dia_atraso, 0 ), 0, c_fec_prestamo, c_fec_prestamo - nvl( p.dia_atraso, 0 )  ),
                         round( months_between( ( c_fec_prestamo + ( p.fec_vencimiento - p.fec_inicio ) ), c_fec_prestamo ), 0 ),
                         'A'
                UNION ALL
                  select d.cod_persona, d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.relacion, d.mto_operacion mto_ope_anterior,
                         greatest( nvl( t.lin_credito, 0 ) + nvl( t.lin_cuotas, 0 ),
                                   nvl( t.sal_facturar, 0 ) + nvl( t.sal_facturado, 0 ) + nvl( t.sal_financiado, 0 ) + nvl( t.sal_cuo_pendientes, 0 ) ) mto_operacion,
                        (select min(z.fec_emision)
                         from ta_tarjetas z
                         where z.nro_cuenta = t.nro_cuenta ) fec_operacion,
                         d.ide_operacion, t.cod_oficina, t.dia_mora, d.saldo sal_anterior,
                         nvl( e.activo, 'N' ) activo,
                         ( nvl( t.sal_facturar, 0 ) + nvl( t.sal_facturado, 0 ) + nvl( t.sal_financiado, 0 ) + nvl( t.sal_cuo_pendientes, 0 ) ) sal_actual,
                         decode( ( nvl( t.sal_facturar, 0 ) + nvl( t.sal_facturado, 0 ) + nvl( t.sal_financiado, 0 ) + nvl( t.sal_cuo_pendientes, 0 ) ),
                                   nvl( d.saldo, 0 ), decode( greatest( nvl( t.lin_credito, 0 ) + nvl( t.lin_cuotas, 0 ),
                                                                        nvl( t.sal_facturar, 0 ) + nvl( t.sal_facturado, 0 ) + nvl( t.sal_financiado, 0 ) + nvl( t.sal_cuo_pendientes, 0 ) ),
                                                              d.mto_operacion, 'N', 'S' ), 'S' ) ind_variacion,
                         decode( nvl( t.dia_mora, 0 ), 0, c_fec_tarjeta, c_fec_tarjeta - nvl( t.dia_mora, 0 ) ) fec_ven_pendiente,
                         round( months_between( ( c_fec_tarjeta + t.dia_mora ), c_fec_tarjeta ), 0 ) pla_operacion,
                         t.fec_ult_pago, 'A' tip_registro
                    from co_inf_personas d, ta_cta_tarjetas t, ge_est_cuentas e, ge_cta_clientes l
                   where d.cod_persona = l.cod_persona
                     and d.ide_operacion = l.nro_cuenta
                     and d.relacion = l.relacion
                     and d.ide_operacion = t.nro_cuenta
                     and d.cod_modulo = t.cod_modulo
                     and d.cod_moneda = t.cod_moneda
                     and e.cod_modulo = t.cod_modulo
                     and e.cod_modalidad = t.cod_modalidad
                     and e.estado = t.estado
                     /*
                     || Esta parte es para verificar que no se vayan operaciones PRESCRIPTAS
                     */
                     and round( months_between( c_fec_tarjeta, c_fec_tarjeta - t.dia_mora ) ) < c_mes_tar_presc
                     /*
                     || Esta parte es que no envíe las cuentas con transacciones prohibídas
                     */
                     and NOT EXISTS( select 1
                                       from ge_tra_prohibidas z
                                      where z.cod_transaccion = 1011 -- No enviar a Informconf
                                        and z.cod_modulo = t.cod_modulo
                                        and z.cod_modalidad = t.cod_modalidad
                                        and z.nro_cuenta = t.nro_cuenta )
              UNION ALL
              /*
              || Envía las Actualizaciones de Operaciones Vencidas, se verifica si varia el saldo pago a cuenta
              || de la operación vencida
              */
        /*CROIOSI-1: Inclusión de Operaciones Vencidas y Sobregiros en la base de Informconf*/
         /*ITC-LCABRERA 08/2014 */
              select d.cod_persona,
                     d.cod_modulo,
                     d.cod_modalidad,
                     d.cod_moneda,
                     d.relacion,
                     d.mto_operacion mto_ope_anterior,
                     v.mto_origen mto_operacion,
                     --v.fec_apertura fec_operacion,
                     decode(v.cod_modalidad, 151, t.fec_apertura, 152, c.fec_apertura,v.fec_apertura) fec_operacion,
                     d.ide_operacion,
                     v.cod_oficina,
                     v.dia_atraso,
                     d.saldo sal_anterior,
                     nvl(e.activo, 'N') activo,
                     v.sal_tot_batch sal_actual, -- SC 18101 hay que reportar situacion al cierre
                     'S' ind_variacion,
                     v.fec_ini_mora fec_ven_pendiente,
                     round(months_between((c_fec_ope_vencida + v.dia_atraso), c_fec_ope_vencida), 0) pla_operacion,
                     v.fec_ult_movimiento,
                     'A' tip_registro
                from co_inf_personas d,
                     ov_cta_vencidas v,
                     ge_est_cuentas  e,
                     ge_cta_clientes l,
                     ge_par_dinamicos g,
                     ta_cta_tarjetas t,
                     cc_cta_corrientes c
               where d.cod_persona = l.cod_persona
                 and d.ide_operacion = l.nro_cuenta
                 and d.relacion = l.relacion
                 and d.ide_operacion = v.nro_cuenta
                 and d.cod_modulo = v.cod_modulo
                 and d.cod_moneda = v.cod_moneda
                 and e.cod_modulo = v.cod_modulo
                 and e.cod_modalidad = v.cod_modalidad
                 and e.estado = v.estado
                 and v.sal_tot_batch <> d.saldo -- SC 18101 hay que reportar situacion al cierre
                 and g.parametro = 'INF_MOD_OPE_VENCIDAS'
                 and g.cod_modulo = v.cod_modulo
                 and g.cod_modalidad = v.cod_modalidad
                 and g.val_parametro = 'S'
                 and v.nro_cta_origen = t.nro_cuenta(+)
                 and v.nro_cta_origen = c.nro_cuenta(+)
                /*
                 || Esta parte es para verificar que no se vayan operaciones PRESCRIPTAS
                 */
                 and round(months_between(c_fec_ope_vencida, c_fec_ope_vencida - v.dia_atraso)) < c_mes_ope_ven_presc

                /*
                 || Esta parte es que no envíe las cuentas con transacciones prohibídas
                 */
                 and NOT EXISTS
               (select 1
                  from ge_tra_prohibidas z
                 where z.cod_transaccion = 1011 -- No enviar a Informconf
                   and z.cod_modulo = v.cod_modulo
                   and z.cod_modalidad = v.cod_modalidad
                   and z.nro_cuenta = v.nro_cuenta)

                UNION ALL
                  /*
                  || Envía las eliminaciones de acuerdo a los criterios de exclusión de los selects
                  || anteriores
                  */
                  select d.cod_persona, d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.relacion, d.mto_operacion mto_ope_anterior,
                         d.mto_operacion, d.fec_operacion, d.ide_operacion, u.cod_oficina, 0 dia_atraso, d.saldo sal_anterior,
                         e.activo, d.saldo sal_actual,
                         'S' ind_variacion, d.fec_ven_pendiente, d.pla_operacion, d.fec_ult_pago, 'E' tip_registro
                    from co_inf_personas d, ge_cuentas u, ge_est_cuentas e
                   where d.ide_operacion = u.nro_cuenta
                     and e.cod_modulo = u.cod_modulo
                     and e.cod_modalidad = u.cod_modalidad
                     and e.estado = u.estado
                     and ( NOT EXISTS( select 1
                                        from ge_cta_clientes x
                                        where x.nro_cuenta = d.ide_operacion
                                          and x.cod_persona = d.cod_persona
                                          and x.relacion = d.relacion ) OR
                       /*
                       || Esta parte es para verificar que no se vayan operaciones PRESCRIPTAS
                       */
                       ( ( d.cod_modulo = 6 AND
                           EXISTS( select 1
                                     from pr_cta_prestamos x
                                    where x.nro_cuenta = d.ide_operacion
                                      and ( months_between( c_fec_prestamo,
                                                            add_months( d.fec_operacion,
                                                                        round( months_between( ( c_fec_prestamo +
                                                                                                 ( x.fec_vencimiento - x.fec_inicio ) ),
                                                                                                 c_fec_prestamo ), 0 ) ) ) ) >= c_mes_pre_presc ) )
                          OR
                         ( d.cod_modulo = 5 AND
                           EXISTS( select 1
                                     from ta_cta_tarjetas x
                                    where x.nro_cuenta = d.ide_operacion
                                    and round( months_between( c_fec_tarjeta, c_fec_tarjeta - x.dia_mora ) ) >= c_mes_tar_presc ) ) )
                          OR
                         ( d.cod_modulo = 15 AND
                           EXISTS( select 1 ----Operaciones Vencidas (Prescriptas)
                                     from ov_cta_vencidas o
                                    where o.nro_cuenta = d.ide_operacion
                                    and round( months_between( c_fec_ope_vencida, c_fec_ope_vencida - o.dia_atraso ) ) >= c_mes_ope_ven_presc )
                           OR
                           EXISTS( select 1 ---Operaciones Canceladas (Pagadas)
                                     from ov_cta_vencidas p, ge_est_cuentas g
                                    where p.nro_cuenta = d.ide_operacion
                                      and p.cod_modulo = g.cod_modulo
                                      and p.cod_modalidad = g.cod_modalidad
                                      and p.estado = g.estado
                                      and g.activo = 'N'))
                          OR
                       /*
                       || Esta parte es que no envíe las cuentas con transacciones prohibídas
                       */
                       EXISTS( select 1
                                 from ge_tra_prohibidas z
                                where z.cod_transaccion = 1011 -- No enviar a Informconf
                                  and z.cod_modulo = u.cod_modulo
                                  and z.cod_modalidad = u.cod_modalidad
                                  and z.nro_cuenta = u.nro_cuenta ) ) )
      order by cod_persona, cod_modulo, cod_modalidad, cod_moneda, relacion;
  ---DYDMR-5609 - Incidencia SAU - ITGF - Datos a Enviar - Informconf
  --funcion que debe retornar el monto total de la operación
  function lf_obt_mto_operacion(p_nro_cuenta pr_cta_prestamos.nro_cuenta%type)
    return number is
    v_mto_operacion pr_cuotas.mto_capital%type := 0;

  begin
    select sum(nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) + nvl(c.mto_int_documentado, 0))
      into v_mto_operacion
      from pr_cuotas c
     where c.nro_cuenta = p_nro_cuenta
     and c.nro_cuota > 0;

    return v_mto_operacion;
  exception
    when others then
      v_mto_operacion := 0;
      return v_mto_operacion;
  end;
  
PROCEDURE LP_INS_INF_TEMPORAL IS
  PRAGMA AUTONOMOUS_TRANSACTION;  
BEGIN
  --borrar datos temporales
  execute immediate 'truncate table co_inf_ope_dia_tmp';


insert into co_inf_ope_dia_tmp
  
select o.cod_persona, decode( p.tipo, 'F', f.pri_nombre, null ) pri_nombre, f.seg_nombre,
                f.pri_apellido, f.seg_apellido,
                decode( nvl( f.cod_sexo, 'M' ), 'M', NULL, pao_mor.fu_obt_ape_casada( f.cod_persona ) ) ape_casada,
                fuo_set_documento( p.cod_tip_documento, p.nro_documento ) nro_documento,
                replace( p.nro_documento, '.', '' )  nro_cedula,
                o.ide_operacion, o.cod_modulo, o.cod_modalidad, o.cod_moneda, o.relacion, o.fec_operacion, o.fec_ven_pendiente,
                o.fec_ult_pago, o.pla_operacion, o.tot_operacion, o.sal_actual, o.fin_registro,
                o.gen_archivo, 'F' tip_persona
           from co_inf_ope_diarias o, ba_personas p, ba_per_fisicas f
          where o.fec_proceso = trunc( p_fec_proceso )
            and nvl( o.estado, 'P' ) in ('P')
            and p.cod_persona = o.cod_persona
            and f.cod_persona = p.cod_persona
      UNION ALL
         select o.cod_persona, j.raz_social pri_nombre, null,
                null, null, null ape_casada,
                fuo_set_documento( p.cod_tip_documento, p.nro_documento ) nro_documento,
                replace( p.nro_documento, '.', '' )  nro_cedula,
                o.ide_operacion, o.cod_modulo, decode(o.cod_modulo,15,o.cod_modalidad, null) cod_modalidad, o.cod_moneda, o.relacion, o.fec_operacion, o.fec_ven_pendiente,
                o.fec_ult_pago, o.pla_operacion, o.tot_operacion, o.sal_actual, o.fin_registro,
                o.gen_archivo, 'J' tip_persona
           from ba_per_juridicas j, co_inf_ope_diarias o, ba_personas p
          where j.cod_persona = o.cod_persona
            and o.fec_proceso = trunc( p_fec_proceso )
            and nvl( o.estado, 'P' ) in ('P')
            and p.cod_persona = o.cod_persona
          order by 4, 5, 2, 3;
          commit;
END LP_INS_INF_TEMPORAL;          

    PRAGMA AUTONOMOUS_TRANSACTION;          
BEGIN
  -- Inicializa la tabla de Procesos, si no se puede inicializar termina el proceso
  v_men_error := NULL;

  begin
       Select 'S', t.fec_ini into v_exi_error ,v_hora_generado
         from co_inf_procesos t
        where trunc(t.fec_ini) = trunc(c_fec_ini)
          and lower(t.comentario) like lower('%El%proceso%Informconf culmin%satisfactoriamente%')
          and rownum = 1;
       --Verificar si ya existen registros de la fecha en co_inf_procesos
  exception
     when others then
       v_exi_error:='N';
  end;
  IF v_exi_error='N' then -- Si no existen registros en co_inf_procesos corre el proceso

        IF v_men_error IS NOT NULL THEN
          v_con_errores := nvl( v_con_errores, 0 ) + 1;
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  'No se pudo inicializar la tabla CO_INF_PROCESOS ' || v_men_error );
          v_mensaje := 'No se pudo inicializar la tabla CO_INF_PROCESOS ' || v_men_error;
          raise v_error;
        END IF;
        pao_mor.pr_ins_informe( c_nom_proceso,
                                c_fec_ini,
                                '*** Proceso iniciado a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
  /*      \*
        || Verifica que NO existan operaciones pendientes ni generadas en la tabla de procesos,
        || si encuentra por lo menos 1, produce un error y termina el proceso.
        *\
        BEGIN
          select sum( decode( nvl( estado, 'P' ), 'P', 1, 0 ) ),
                 sum( decode( nvl( estado, 'P' ), 'G', 1, 0 ) )
            into v_cont_pendientes, v_cont_generados
            from co_inf_ope_diarias
           where fec_proceso <= c_fec_actual
             and estado IN( 'P', 'G' );
        EXCEPTION
          when v_error then
           raise v_error;
          when others then
            v_cont_pendientes := 0;
            v_cont_generados := 0;
            v_con_errores := nvl( v_con_errores, 0 ) + 1;
            pao_mor.pr_ins_informe( c_nom_proceso,
                                    c_fec_ini,
                                    'No se pudo determinar la cantidad de registro NO PROCESADOS.' );
        END;*/
        ---Mejoras en proceso Informconf
        /*IF nvl( v_cont_pendientes, 0 ) > 0 OR
           nvl( v_cont_generados, 0 ) > 0 THEN
          v_con_errores := nvl( v_con_errores, 0 ) + 1;
          v_mensaje := ' ' || ltrim( rtrim( to_char( nvl( v_cont_pendientes, 0 ), '999G999G999G990' ) ) ) ||
                       ' registros PENDIENTES de procesar y ' ||
                       ltrim( rtrim( to_char( nvl( v_cont_generados, 0 ), '999G999G999G990' ) ) ) ||
                       ' registros GENERADOS y no confirmados.';
          raise v_error;
        END IF;*/

        /************ Inserto datos de cliente nuevos para el informe a informconf ************/

        pao_mor.pr_ins_informe( c_nom_proceso,
                                c_fec_ini,
                                '*** Va iniciar el Cursor de Inserción a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
        v_nro_registro := 0;
        FOR di IN dat_insertar LOOP
          v_nro_registro := v_nro_registro + 1;
          IF round( v_nro_registro / 10 ) = v_nro_registro / 10 THEN
            pao_mor.pr_ins_informe( c_nom_proceso,
                                    c_fec_ini,
                                    '*** Insertando el registro Nº ' || to_char( v_nro_registro ) || ' a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
          END IF;
          BEGIN
              SELECT nvl(cli_especial, 'N'), nvl(cli_confidencial, 'N')
                 INTO v_cli_especial, v_cli_confidencial
                 FROM ge_clientes
                WHERE cod_persona = di.cod_persona;
          EXCEPTION
               WHEN OTHERS THEN
                  v_cli_especial := 'N';
                  v_cli_confidencial := 'N';
          END;
          IF (v_cli_especial <> 'S' and v_cli_confidencial <> 'S') THEN

            --Verificar fecha de ultimo pago que sea un dato consistente para tarjetas
            If di.cod_modulo = 5 and di.fec_ult_pago < di.fec_operacion then
              di.fec_ult_pago := null;
            End if;
            BEGIN
              insert into co_inf_ope_diarias( fec_proceso,
                                              cod_persona,
                                              ide_operacion,
                                              cod_modulo,
                                              cod_moneda,
                                              relacion,
                                              fec_operacion,
                                              fec_ven_pendiente,
                                              fec_ult_pago,
                                              pla_operacion,
                                              tot_operacion,
                                              sal_actual,
                                              fin_registro,
                                              estado,
                                              gen_archivo,
                                              cod_modalidad )
                                      values( di.fec_proceso,
                                              di.cod_persona,
                                              di.ide_operacion,
                                              di.cod_modulo,
                                              di.cod_moneda,
                                              di.relacion,
                                              di.fec_operacion,
                                              di.fec_ven_pendiente,
                                              di.fec_ult_pago,
                                              di.pla_operacion,
                                              di.tot_operacion,
                                              di.sal_actual,
                                              di.fin_registro,
                                              di.estado,
                                              'S' ,
                                              di.cod_modalidad);
            EXCEPTION
              when v_error then
                raise v_error;
              when others then
                v_con_errores := nvl( v_con_errores, 0 ) + 1;
                pao_mor.pr_ins_informe( c_nom_proceso,
                                        c_fec_ini,
                                        'Error al insertar CO_DAT_INFORMCONF nuevos -  cliente: ' || di.cod_persona || ', Cuenta: ' ||
                                         di.ide_operacion || ', para: ' || di.fin_registro || '; ' || sqlerrm);
            END;
          else 
             pao_mor.pr_ins_informe( 'PR_PRO_INF_DIARIO',
                            sysdate,
                            'Cliente especial. Cod Persona: ' || di.cod_persona );
          

          END IF;
        commit;
        END LOOP;
        pao_mor.pr_ins_informe( c_nom_proceso,
                                c_fec_ini,
                                '*** Cursor de Actualización iniciado a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
        /****************  Generacion de la informacion a ser enviada ****************/
        v_nro_registro := 0;
        FOR da IN dat_actualizar LOOP
          v_nro_registro := v_nro_registro + 1;
          IF round( v_nro_registro / 100 ) = v_nro_registro / 100 THEN
            pao_mor.pr_ins_informe( c_nom_proceso,
                                    c_fec_ini,
                                    '*** Procesando el registro Nº ' || to_char( v_nro_registro ) || ' a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
          END IF;
          BEGIN
            --AP.2493 agregar la condicion del parámetro ENV_INFORMCONF
            select nvl( val_parametro, 'S' )
              into v_cli_informconf
              from ba_per_dat_adicionales
             where cod_persona = da.cod_persona
               and parametro = 'ENV_INFORMCONF';
          EXCEPTION
            when others then
              v_cli_informconf := 'S';
          END;
          v_reg := NULL;
          v_reg.fec_proceso       := trunc( p_fec_proceso );
          v_reg.cod_persona       := da.cod_persona;
          v_reg.ide_operacion     := da.ide_operacion;
          v_reg.cod_modulo        := da.cod_modulo;
          v_reg.cod_modalidad     := da.cod_modalidad;
          v_reg.cod_moneda        := da.cod_moneda;
          v_reg.relacion          := da.relacion;
          v_reg.fec_operacion     := da.fec_operacion;
          v_reg.fec_ven_pendiente := da.fec_ven_pendiente;
          v_reg.fec_ult_pago      := da.fec_ult_pago;
          v_reg.pla_operacion     := da.pla_operacion;
          v_reg.estado            := 'P';
          --Verificar fecha de ultimo pago que sea un dato consistente para tarjetas
          If v_reg.cod_modulo = 5 and v_reg.fec_ult_pago < v_reg.fec_operacion then
            v_reg.fec_ult_pago := null;
          End if;
          /*
          || Verificaciones para incluir la cuenta:
          || 1) Que los días de atraso estén dentro de los parámetros
          || 2) Si es tarjeta que la oficina sea distinto a la de ventas de tarjetas
          || 3) Que el saldo sea mayor o igual al paràmetro por moneda
          || 4) Que la cuenta esté Activa
          || 5) Que el cliente no esté marcado como 'N'en campo Incluir Archivo Informconf
          */
          IF nvl( da.dia_atraso, 0 ) between v_dia_atr_ini and v_dia_atr_fin AND
             ( ( da.cod_modulo = 5 ) OR
               ( da.cod_modulo <> 5 ) ) AND
             /*( ( da.cod_moneda = v_mon_local  AND nvl( da.sal_actual, 0 ) >= v_mto_min_mon_local ) OR
               ( da.cod_moneda = v_mon_fuerte AND nvl( da.sal_actual, 0 ) >= v_mto_min_mon_fuerte ) ) AND */--comentado por  DYDMR-19748-
             da.activo = 'S' AND
             v_cli_informconf = 'S' AND
             da.tip_registro = 'A' THEN
            -- Si varió el saldo de la cuenta, inserta un registro de inserción para informconf
            IF da.ind_variacion = 'S' THEN
              -- Primero inserta una eliminación por el saldo anterior.
              v_reg.fin_registro  := 'E';
              v_reg.sal_actual    := da.sal_anterior;
              v_reg.tot_operacion := da.mto_ope_anterior;
              v_reg.cod_modalidad := da.cod_modalidad;
              -- Proceso de inserción
              v_men_error := NULL;
              pao_mor.pr_ins_inf_ope_diaria( v_reg, v_men_error );
              IF v_men_error IS NOT NULL THEN
                v_con_errores := nvl( v_con_errores, 0 ) + 1;
                pao_mor.pr_ins_informe( c_nom_proceso,
                                        c_fec_ini,
                                        'No pudo insertar el registro de eliminación de Informconf para ' ||
                                        da.cod_persona || '; ' || v_men_error );
              END IF;
             
			 --Se inserta con el nuevo saldo si el saldo esta en el rango parametrizado DYDMR-19748 
              IF ( ( da.cod_moneda = v_mon_local  AND nvl( da.sal_actual, 0 ) >= v_mto_min_mon_local ) OR
               ( da.cod_moneda = v_mon_fuerte AND nvl( da.sal_actual, 0 ) >= v_mto_min_mon_fuerte ) )
               THEN
				 -- Luego inserta el nuevo saldo de la cuenta
				  v_reg.fin_registro  := 'I';
				  v_reg.sal_actual    := da.sal_actual;
				 ---DYDMR-5609 - Incidencia SAU - ITGF - Datos a Enviar - Informconf 
				 if da.cod_modulo = 6 then
					 v_reg.tot_operacion := lf_obt_mto_operacion(da.ide_operacion);
				  else
					 v_reg.tot_operacion := da.mto_operacion;
				  end if;
				  /*
				  || Verifica que el saldo no sea mayor que el total del comprobante.
				  || Este caso se produce con las tarjetas, cuando varia alguno de los saldos.
				  */
				  IF v_reg.sal_actual > v_reg.tot_operacion THEN
					v_reg.tot_operacion := v_reg.sal_actual;
				  END IF;
				  -- Proceso de inserción
				  v_men_error := NULL;
				  pao_mor.pr_ins_inf_ope_diaria( v_reg, v_men_error );
				  IF v_men_error IS NOT NULL THEN
					v_con_errores := nvl( v_con_errores, 0 ) + 1;
					pao_mor.pr_ins_informe( c_nom_proceso,
											c_fec_ini,
											'No pudo insertar el registro de inserción de Informconf para ' ||
											da.cod_persona || '; ' || v_men_error );
				  END IF;
			  END IF; 
            END IF;
          ELSIF nvl( da.dia_atraso, 0 ) < v_dia_atr_ini AND
                 ( ( da.cod_modulo = 5 )    OR ( da.cod_modulo <> 5 ) )    AND
                 ( ( da.cod_moneda = v_mon_local ) OR ( da.cod_moneda = v_mon_fuerte ) ) AND
                     da.activo in('S','N')  AND  -- para las cuentas que son canceladas con el pago de la ultima cuota
                     v_cli_informconf   = 'S' AND
                     da.tip_registro  = 'A' THEN
              -- Si varió el saldo de la cuenta y el atraso actual es menor al rango inicial inserta un registro de exclución para informconf
              -- Primero inserta una eliminación por el saldo ACTUAL.
              v_reg.fin_registro  := 'E';
              v_reg.sal_actual    := da.sal_actual;
              v_reg.tot_operacion := da.mto_operacion;
              -- Proceso de insercion
              v_men_error := NULL;
              pao_mor.pr_ins_inf_ope_diaria( v_reg, v_men_error );
              IF v_men_error IS NOT NULL THEN
                v_con_errores := nvl( v_con_errores, 0 ) + 1;
                pao_mor.pr_ins_informe( c_nom_proceso,
                                        c_fec_ini,
                                        'No pudo insertar el registro de eliminación de Informconf para ' ||
                                        da.cod_persona || '; ' || v_men_error );
              END IF;

          ELSIF /*v_cli_informconf = 'N' and*/ da.tip_registro  = 'E' then --AP 2493 Comentado para que inserte el registro de eliminación con solo el tip_registro=E
            -- Si no cumplió con los requisitos para la inserción de la cuenta,
            -- entonces inserta un registro de eliminación para informconf
            v_reg.fin_registro := 'E';
            v_reg.sal_actual    := da.sal_actual;
            v_reg.tot_operacion := da.mto_operacion;
            v_men_error := NULL;
            pao_mor.pr_ins_inf_ope_diaria( v_reg, v_men_error );
            IF v_men_error IS NOT NULL THEN
              v_con_errores := nvl( v_con_errores, 0 ) + 1;
              -- OMM DYDMR-4971 Para tratar el error correctamente
              v_men_error   := substr('No pudo insertar el registro de eliminación definitiva de Informconf para ' ||da.cod_persona || '; ' || v_men_error, 1, 1450) ;
              pao_mor.pr_ins_informe( c_nom_proceso,
                                      c_fec_ini,
                                      v_men_error);  
            END IF;
          END IF;
          commit;
        END LOOP;

        pao_mor.pr_ins_informe( c_nom_proceso,
                                c_fec_ini,
                                '*** Se procesaron ' || to_char( v_nro_registro ) || ' registros, hasta las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
 
     --Carga Tabla Temporal 
      LP_INS_INF_TEMPORAL;
      
      pao_mor.pr_ins_informe( 'LP_INS_INF_TEMPORAL',
                                c_fec_ini,
                                '*** Se procesaron ' || to_char( v_nro_registro ) || ' registros, hasta las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
      
 --Mejoras en proceso de envio datos a Informconf
 /*       pao_mor.pr_gen_inf_archivo( trunc( p_fec_proceso ) );
        -- Inserta registro del proceso.
        IF nvl( v_con_errores, 0 ) = 0 THEN
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  '*** ¡El proceso de interface de Informconf culminó satisfactoriamente a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs.! ***',
                                  FALSE );
        ELSE
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  'El proceso de interface de Informconf culminó con ' || to_char( v_con_errores ) ||
                                  ' error(es).',
                                  FALSE );
        END IF;*/
  ELSE -- si existen registros en co_inf_procesos no corre el proceso
      v_mensaje := 'Atencion: Ya se han generado los archivos de Informconf del dia de hoy '||to_char(v_hora_generado,'DD/MM/YYYY')|| ' a las '||to_char(v_hora_generado,'HH24:mi:ss')|| ' hs, Favor detener el proceso seleccionando el boton NO en el cuadro de diálogo. ' || v_men_error;
      raise v_error;
  END IF;
EXCEPTION
  when v_error then
    RAISE_APPLICATION_ERROR( -20542, v_mensaje );
  when others then
    pao_mor.pr_ins_informe( c_nom_proceso,
                            c_fec_ini,
                            'ERROR. En el proceso de interface con Informconf.');

END PR_PRO_INF_DIARIO;
/* Inserta registro de la tabla CO_INF_OPE_DIARIAS */
PROCEDURE PR_INS_INF_OPE_DIARIA( p_registro  IN  CO_INF_OPE_DIARIAS%ROWTYPE,
                                 p_men_error OUT CO_INF_PROCESOS.COMENTARIO%TYPE
                                 ) IS
  verr CO_INF_PROCESOS.COMENTARIO%TYPE;
BEGIN
  BEGIN
    insert into co_inf_ope_diarias( fec_proceso,
                                    cod_persona,
                                    ide_operacion,
                                    cod_modulo,
                                    cod_moneda,
                                    relacion,
                                    fec_operacion,
                                    fec_ven_pendiente,
                                    fec_ult_pago,
                                    pla_operacion,
                                    tot_operacion,
                                    sal_actual,
                                    fin_registro,
                                    estado,
                                    gen_archivo,
                                    cod_modalidad )
                            values( trunc( p_registro.fec_proceso ),
                                    p_registro.cod_persona,
                                    p_registro.ide_operacion,
                                    p_registro.cod_modulo,
                                    p_registro.cod_moneda,
                                    p_registro.relacion,
                                    p_registro.fec_operacion,
                                    p_registro.fec_ven_pendiente,
                                    p_registro.fec_ult_pago,
                                    p_registro.pla_operacion,
                                    p_registro.tot_operacion,
                                    p_registro.sal_actual,
                                    p_registro.fin_registro,
                                    p_registro.estado,
                                    'S' ,
                                    p_registro.cod_modalidad);
  EXCEPTION
    when DUP_VAL_ON_INDEX then
         verr := null ;
    when others then
      -- OMM DYDMR-4971 Para tratar el error correctamente
      if sqlcode = 0 then
         verr := null ;
      else 
         verr := 'ERROR. Al insertar el registro diario para el cliente: ' || p_registro.cod_persona || ', Cuenta: ' ||
                 p_registro.ide_operacion || ', para: ' || p_registro.fin_registro || '; ' || sqlerrm;
      end if ;
  END;
  p_men_error := verr;
END PR_INS_INF_OPE_DIARIA;
/* Generación de datos para Informconf a través del webservice - LA-16/07/2015*/
PROCEDURE PR_GEN_INF_ARCHIVO( P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6) ) )  IS

  CURSOR registros( p_tipo VARCHAR2 )
      IS select o.cod_persona, t.pri_nombre, t.seg_nombre,
                t.pri_apellido, t.seg_apellido, t.ape_casada,
                t.nro_documento,
                replace( t.nro_documento, '.', '' )  nro_cedula,
                o.ide_operacion, o.cod_modulo, o.cod_modalidad, o.cod_moneda, o.relacion, o.fec_operacion, o.fec_ven_pendiente,
                o.fec_ult_pago, o.pla_operacion, o.tot_operacion, o.sal_actual, o.fin_registro,
                nvl(pao_mor.fu_obt_inf_moneda(o.cod_moneda), ' ') cod_mon_env,
                o.gen_archivo, 'F' persona
           from co_inf_ope_dia_tmp t, co_inf_ope_diarias o
          where t.ide_operacion = o.ide_operacion
            and t.cod_persona = o.cod_persona
            and t.relacion = o.relacion
            and o.fin_registro = p_tipo
            and nvl( o.estado, 'P' ) in ('E','P')
            and t.tip_persona = 'F'
            and t.fin_registro = o.fin_registro
            and o.fec_proceso = trunc( p_fec_proceso )
      UNION ALL
         select t.cod_persona, t.pri_nombre, null,
                null, null, null ape_casada,
                t.nro_documento,
                t.nro_cedula,
                o.ide_operacion, o.cod_modulo, o.cod_modalidad, o.cod_moneda, o.relacion, o.fec_operacion, o.fec_ven_pendiente,
                o.fec_ult_pago, o.pla_operacion, o.tot_operacion, o.sal_actual, o.fin_registro,
                nvl(pao_mor.fu_obt_inf_moneda(o.cod_moneda), ' ') cod_mon_env,
                o.gen_archivo, 'J' persona
           from co_inf_ope_dia_tmp t, co_inf_ope_diarias o
          where t.ide_operacion = o.ide_operacion
            and t.cod_persona = o.cod_persona
            and t.relacion = o.relacion
            and o.fin_registro = p_tipo
            and nvl( o.estado, 'P' ) in ('E','P')
            and t.tip_persona = 'J'
            and t.fin_registro = o.fin_registro
            and o.fec_proceso = trunc( p_fec_proceso )
          order by 4, 5, 2, 3;

         ----
   ----- LA 07/2015 --Webservice informconf
    v_par_ingreso   VARCHAR2(22);
    v_retorno       VARCHAR2(2);
    v_cod_err_inf   VARCHAR2(10);
    v_respuesta     VARCHAR2(4000);
    v_ok            VARCHAR2(1); -- Indica si el socket se corto o no     
    v_estado        co_inf_ope_diarias.estado%TYPE; 
    v_msj_error     VARCHAR(4000) := NULL; 
    v_det_error     VARCHAR(200) := NULL; 
   -----
  c_fec_ini     CONSTANT DATE := sysdate;
  c_nom_proceso CONSTANT VARCHAR2(30) := 'PR_GEN_INF_ARCHIVO';
  c_cod_segur   CONSTANT NUMBER(8) := to_number( fug_obt_pardinamico( 'INF_COD_SEGURIDAD' ) );
  v_nom_archivo VARCHAR2(100);
  v_buffer      VARCHAR2(4000);
  v_tip         VARCHAR2(1);
  v_tot_regs    NUMBER;
  v_sum_docs    NUMBER;
  v_cedula      VARCHAR2(50);
  v_es_ci       NUMBER;
  v_usuario          VARCHAR2(60) := FUG_OBT_PARENTES( fug_obt_pardinamico('GEN_COD_ENTE_INFORMCONF'),'USR_INFORMCONF');
  v_clave            VARCHAR2(50) := fug_des_clave(fug_obt_parentes( fug_obt_pardinamico('GEN_COD_ENTE_INFORMCONF') , 'USR_PAS_INFORMCONF'));    --fug_des_clave(fug_obt_parentes(9000, 'USR_PAS_INFORMCONF'));
  v_ide_operacion    ge_cuentas.nro_cuenta%type;
  v_sep_identificador  varchar2(10) := nvl(fug_obt_pardinamico('INF_SEP_IDENTIFICADOR'),'N');
  v_relacion         VARCHAR2(1);
  
PRAGMA AUTONOMOUS_TRANSACTION;  
BEGIN
   pao_mor.pr_ins_informe( c_nom_proceso,
                          c_fec_ini,
                          '*** Proceso iniciado a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
 
  
  FOR i IN 1..2 LOOP
    -- Inicializa las variables para el proceso
    v_tip      := translate( i, '12', 'EI' );
    v_tot_regs := 0;
    v_sum_docs := 0;
    v_es_ci    := 0;
    v_cedula   := NULL;
    v_buffer   := NULL;
    
    pao_mor.pr_ins_informe( c_nom_proceso,
                            c_fec_ini,
                            '*** Inicia el proceso de "' || v_tip || '" a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );

    FOR r IN registros( v_tip ) LOOP
      if r.gen_archivo = 'S' then
         v_tot_regs := nvl( v_tot_regs, 0 ) + 1;
         v_es_ci := 0;
         BEGIN
           v_es_ci := nvl( to_number( r.nro_cedula ), 0 );
         EXCEPTION
          when others then
               v_es_ci := 0;
         END;
         IF nvl( v_es_ci, 0 ) > 0 THEN
            v_cedula := r.nro_documento;
         ELSE
            v_cedula := r.nro_documento;
         END IF;
         /*
         v_buffer := '04'|| --codigo de operacion 04(Informconf)
           lpad( to_char( nvl( v_afiliado, 0 ) ), 6, ' ' ) ||--codigo de persona
   lpad( nvl( substr( ltrim( rtrim( v_cedula ) ), 1, 15 ), ' ' ), 15, ' ' ) ||--documento
            lpad( nvl( substr( r.pri_nombre, 1, 65 ), ' ' ), 65, ' ' ) ||--primer nombre
             lpad( nvl( substr( r.seg_nombre, 1, 15 ), ' ' ), 15, ' ' ) || --segundo nombre
             lpad( nvl( substr( r.pri_apellido, 1, 20 ), ' ' ), 20, ' ' );-- primer apellido
         
                  --lpad( nvl( to_char( p_fec_proceso, 'YYYYMMDD' ), ' ' ), 8, ' ' ) ||
         IF r.ape_casada IS NULL THEN
      v_buffer := v_buffer || lpad( nvl( substr( r.seg_apellido, 1, 20 ), ' ' ), 20, ' ' );--segundo apellido
         ELSE
            v_buffer := v_buffer || lpad( ' ', 20, ' ' );
         END IF;
         v_buffer := v_buffer ||
            lpad( nvl( substr( r.ape_casada, 1, 20 ), ' ' ), 20, ' ' ) ||--apellido de casada
        lpad( nvl( to_char( r.fec_operacion,'DD/MM/YYYY' ), ' ' ), 10, ' ' ) ||--fecha operacion
        lpad( nvl( substr( r.ide_operacion, 1, 25 ), ' ' ), 25, ' ' ) ||--nro operacion
         lpad( to_char( nvl( pao_mor.fu_obt_inf_operacion( r.cod_modulo, r.relacion, r.cod_modalidad ), 0 ) ), 2, 0 )||--tipo de operacion
                  lpad( ltrim( replace( to_char( nvl( r.tot_operacion, 0 ), '99999999999999999999' ), '.' ) ), 20, 0 ) ||--monto 
                  lpad( nvl( pao_mor.fu_obt_inf_moneda( r.cod_moneda ), ' ' ), 1, ' ' );--moneda
         IF nvl( length( r.pla_operacion ), 0 ) > 3 THEN
            v_buffer := v_buffer || '999';--plazo
         ELSE
            v_buffer := v_buffer || lpad( to_char( nvl( r.pla_operacion, 0 ) ), 3, ' ' );--plazo
         END IF;
         v_buffer := v_buffer || lpad( nvl( to_char( r.fec_ven_pendiente, 'DD/MM/YYYY' ), ' ' ), 10, ' ' ) ||--fecha vencimiento
                  lpad( nvl( to_char( r.fec_ult_pago, 'DD/MM/YYYY' ), ' ' ), 10, ' ' ) ||--fecha ult pago
                  lpad( ltrim( replace( to_char( nvl( r.sal_actual, 0 ), '99999999999999999999' ), '.' ) ), 20, ' ' ) ||--saldo
                  lpad( nvl( r.fin_registro, ' ' ), 1, ' ' );--registro
         */
         v_sum_docs := nvl( v_sum_docs, 0 ) + v_es_ci;
         
         if r.relacion = 'P' and r.cod_modulo = 6 then
                  v_relacion := 1;
               elsif r.relacion = 'C' and r.cod_modulo = 6 then
                  v_relacion := 2;
               elsif /*r.relacion = 'P' and */r.cod_modulo = 5 then
                  v_relacion := 3;
               else
                  v_relacion := 1;
               end if;
               
         if r.cod_modulo = 5 then
                  v_ide_operacion := r.ide_operacion;
               else
                   if v_sep_identificador = 'S' then
                      v_ide_operacion := fuo_set_documento(1,r.ide_operacion);
                   else
                      v_ide_operacion := r.ide_operacion;
                   end if;
         end if;
         
         if r.persona = 'F' then
                 v_buffer := '6'|| '#' || v_usuario || '#' || v_clave || '#' || substr(v_cedula,1,15) || '#' || substr(nvl(lf_obt_dato(r.pri_apellido),' '),1,20)
                    || '#' || substr(nvl(lf_obt_dato(r.seg_apellido),' '),1,20) || '#' || substr(nvl(lf_obt_dato(r.ape_casada),' '),1,20) || '#' || substr(nvl(lf_obt_dato(r.pri_nombre),' '),1,65) || '#' || substr(nvl(lf_obt_dato(r.seg_nombre),' '),1,15)
                    || '#' || nvl(to_char(r.fec_operacion,'dd/mm/yyyy'),' ') || '#' || to_char(r.fec_ult_pago,'dd/mm/yyyy') || '#' || to_char(r.fec_ven_pendiente,'dd/mm/yyyy') || '#' || nvl( r.cod_mon_env, ' ')
                    || '#' || r.tot_operacion || '#' || v_ide_operacion || '#' || r.cod_persona || '#' || r.pla_operacion
                    || '#' || r.sal_actual || '#' || v_relacion || '#' || r.fin_registro;
         else
                 v_buffer := '27'|| '#' || v_usuario || '#' || v_clave || '#' || substr(r.nro_documento,1,15) || '#' || r.cod_persona
                    || '#' || to_char(r.fec_operacion,'dd/mm/yyyy') || '#' || to_char(r.fec_ult_pago,'dd/mm/yyyy') || '#' || to_char(r.fec_ven_pendiente,'dd/mm/yyyy') || '#' || nvl( r.cod_mon_env, ' ')
                    || '#' || r.tot_operacion || '#' || v_ide_operacion || '#' || r.pla_operacion
                    || '#' || substr(r.pri_nombre,1,65) || '#' || r.fin_registro
                    || '#' || r.sal_actual || '#' || v_relacion;
         end if;
         
      --llama a socket
          v_ok := fue_env_tcp_mensajes(g_servidor,
                                       g_puerto,
                                       g_tie_espera,
                                       v_buffer,
                                       v_respuesta);
          ------
                /*
        || Verifica que NO existan operaciones pendientes ni generadas en la tabla de procesos,
        || si encuentra por lo menos 1, produce un error y termina el proceso.
        */

          IF v_ok != 'S' THEN
           v_estado := 'E';
           g_reauto := 'S';
           v_msj_error := 'Error con el Socket Informconf. '||v_respuesta;
           v_det_error := 'Error con el Socket BBVA-Informconf.' ;
           v_retorno := substr(v_respuesta, 1, 2);
          ELSE
            v_retorno := substr(v_respuesta, 1, 2);
            v_cod_err_inf := substr(v_respuesta, 3, 7);
            IF v_retorno != '00' THEN
              v_estado := 'E';
              g_reauto := 'S';
              v_msj_error := 'Error Webservice Informconf. '||v_respuesta;
              v_det_error := 'Error Webservice Informconf. ' ||v_retorno;
              --error en la conexion
            ELSE
               --DYDMR-10502 se comenta la condición debido a que se marca con error registros correctos con comentarios
			   /*if nvl(v_cod_err_inf, 0) < 0 then -- DYDMR-8681 Para marcar con error la respuesta de Informconf
                  v_estado := 'E';
                  v_det_error := substr(v_respuesta, 3, 180);
                else*/
                   v_estado := 'G';
                   v_det_error := '' ;
                /*end if ;*/
            END IF;
      end if;
      BEGIN
        update co_inf_ope_diarias
                     set estado = v_estado, -- (E)rror (G)enerado
                         det_error = v_det_error,
                         cod_respuesta = v_retorno
         where fec_proceso = trunc( p_fec_proceso )
           and cod_persona = r.cod_persona
           and ide_operacion = r.ide_operacion
           and fin_registro = r.fin_registro;
      EXCEPTION
        when others then
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  'No se pudo actualiza el estado de la cuenta ' || r.ide_operacion ||
                                  ', cliente ' || r.cod_persona || ', Relación ' || r.relacion ||
                                  ', Finalidad ' || r.fin_registro );
      END;
              IF nvl(v_msj_error,'X')<> 'X' THEN
                pao_mor.pr_ins_informe( c_nom_proceso,
                                        c_fec_ini,
                                        r.ide_operacion ||', cliente: ' || r.cod_persona 
                                        || ', Relación: ' || r.relacion 
                                        || ', Finalidad: ' || r.fin_registro
                                        || ', Msj. Error: ' ||v_msj_error, FALSE);
               v_msj_error := null;
               v_det_error := null;
             END IF;
    END IF;
    commit;

    END LOOP;

  END LOOP;
  
  pao_mor.pr_ins_informe( c_nom_proceso,
                          c_fec_ini,
                          '*** Proceso finalizado a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
EXCEPTION
  when others then
    pao_mor.pr_ins_informe( c_nom_proceso,
                          c_fec_ini,
                          '*** Error al finalizar el proceso ', TRUE );
END PR_GEN_INF_ARCHIVO;
/* Procesa los registros diarios confirmados por Informconf */
PROCEDURE PR_PRO_INF_CONFIRMAR( P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6) ) ) IS
  c_fec_ini     DATE := sysdate;
  c_nom_proceso CONSTANT VARCHAR2(30) := 'PR_PRO_INF_CONFIRMAR';
  --
  v_plazo       NUMBER(3);
  v_cedula      VARCHAR2(50);
  v_es_ci       NUMBER;
  v_no_procesar EXCEPTION;
  v_fec_proceso date;
  --
  v_mensaje     VARCHAR2(2000);
  v_error       EXCEPTION;
  v_men_error   CO_INF_PROCESOS.COMENTARIO%TYPE;
--
  CURSOR cuentas
      IS select o.fec_proceso, o.cod_persona, o.ide_operacion, o.cod_modulo, o.cod_modalidad, o.cod_moneda, o.relacion,
                o.fec_operacion, o.fec_ven_pendiente, o.fec_ult_pago, o.pla_operacion, o.tot_operacion,
                o.sal_actual, o.fin_registro, x.pri_nombre, x.seg_nombre, x.pri_apellido, x.seg_apellido,
                x.ape_casada, x.nro_documento, o.estado
           from co_inf_ope_diarias o, co_inf_ope_dia_tmp x
          where o.fec_proceso = trunc( v_fec_proceso )
            and nvl( o.estado, 'P' ) = 'G'
            and o.cod_persona = x.cod_persona
            and o.ide_operacion = x.ide_operacion
            and o.fin_registro = x.fin_registro   
            and not exists (select 1 ---> Condicion para no confirmar I-ncl que tengan E-xcl con Error o Procesado
                              from co_inf_ope_diarias r 
                             where r.fec_proceso = o.fec_proceso
                               and r.ide_operacion = o.ide_operacion
                               and r.cod_persona = o.cod_persona
                               and r.fin_registro = 'E'
                               and o.fin_registro = 'I'
                               and r.estado in ('E','P'))
          order by o.fin_registro, o.cod_persona, o.ide_operacion;
BEGIN
     BEGIN
         Select 'S', t.fec_ini into v_exi_error ,v_hora_generado
           from co_inf_procesos t
          where t.nom_proceso= c_nom_proceso
            and t.comentario like '*** Proceso finalizado a las%'
            and trunc(t.fec_ini) =trunc(c_fec_ini)
            and  rownum = 1;
     EXCEPTION
       WHEN OTHERS THEN
            v_exi_error:='N';
     END;
     IF v_exi_error='N' or nvl(g_reproceso,'N') = 'S' then -- Si aun no corrio el proceso co_inf_procesos se ejecuta este proceso
          if fug_obt_tip_implementacion = 2 then
            v_fec_proceso := fug_obt_pardinamico('FEC_CONF_INFORMCONF');
          else
            v_fec_proceso := p_fec_proceso;
          end if;
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  '*** Proceso iniciado a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
          IF NOT pao_mor.fu_pue_procesar( trunc( v_fec_proceso ) ) THEN
            raise v_no_procesar;
          END IF;

          FOR c IN cuentas LOOP
            IF c.fin_registro = 'E' THEN
             --Enviar datos al histórico antes de eliminar
             pao_mor.pr_ins_inf_historico (c.cod_persona, c.ide_operacion, c.relacion, v_fec_proceso);
                         
              BEGIN
                delete co_inf_personas
                 where cod_persona = c.cod_persona
                   and ide_operacion = c.ide_operacion
                   and relacion = c.relacion;
              EXCEPTION
                when v_no_procesar then
                  raise v_no_procesar;
                when others then
                  pao_mor.pr_ins_informe( c_nom_proceso,
                                          c_fec_ini,
                                          'No se pudo eliminar el saldo para el cliente ' || c.cod_persona ||
                                          ', Cuenta ' || c.ide_operacion || ', Relación ' || c.relacion );

                  goto no_actualizar;
              END;
            ELSIF c.fin_registro = 'I' THEN
              -- Verifica que el plazo de la operación no sea mayor a 999, ya que este el el màximo
              -- plazo en meses que soporta Informconf
              IF nvl( c.pla_operacion, 0 ) > 999 THEN
                v_plazo := 999;
              ELSE
                v_plazo := nvl( c.pla_operacion, 0 );
              END IF;
              v_es_ci := 0;
              BEGIN
                v_es_ci := nvl( to_number( c.nro_documento ), 0 );
              EXCEPTION
                when v_no_procesar then
                  raise v_no_procesar;
                when others then
                  v_es_ci := 0;
              END;
              IF nvl( v_es_ci, 0 ) > 0 THEN
                v_cedula := c.nro_documento;
              ELSE
                v_cedula := c.nro_documento;
              END IF;
              BEGIN
                insert into co_inf_personas( cod_persona,
                                             cod_modulo,
                                             cod_modalidad,
                                             cod_moneda,
                                             relacion,
                                             cod_afiliado,
                                             fec_informacion,
                                             nro_documento,
                                             pri_nombre,
                                             seg_nombre,
                                             pri_apellido,
                                             seg_apellido,
                                             ape_casada,
                                             fec_operacion,
                                             ide_operacion,
                                             cod_inf_operacion,
                                             mto_operacion,
                                             cod_inf_moneda,
                                             pla_operacion,
                                             fec_ven_pendiente,
                                             fec_ult_pago,
                                             saldo )
                                     values( c.cod_persona,
                                             c.cod_modulo,
                                             c.cod_modalidad,
                                             c.cod_moneda,
                                             c.relacion,
                                             v_afiliado,
                                             trunc( v_fec_proceso ),
                                             v_cedula,
                                             c.pri_nombre,
                                             c.seg_nombre,
                                             c.pri_apellido,
                                             decode( c.ape_casada, NULL, c.seg_apellido, NULL ),
                                             c.ape_casada,
                                             c.fec_operacion,
                                             c.ide_operacion,
                                             nvl( pao_mor.fu_obt_inf_operacion( c.cod_modulo, c.relacion , c.cod_modalidad), 0 ),
                                             c.tot_operacion,
                                             nvl( pao_mor.fu_obt_inf_moneda( c.cod_moneda ), ' ' ),
                                             v_plazo,
                                             c.fec_ven_pendiente,
                                             c.fec_ult_pago,
                                             c.sal_actual );
              EXCEPTION
                when v_no_procesar then
                  raise v_no_procesar;
                when others then
                  pao_mor.pr_ins_informe( c_nom_proceso,
                                          c_fec_ini,
                                          'No se pudo insertar el saldo para el cliente ' || c.cod_persona ||
                                          ', Cuenta ' || c.ide_operacion || ', Relación ' || c.relacion );
                  goto no_actualizar;
              END;
            END IF;
            BEGIN
              update co_inf_ope_diarias
                 set estado = 'R'
               where cod_persona = c.cod_persona
                 and ide_operacion = c.ide_operacion
                 and relacion = c.relacion
         and fin_registro = c.fin_registro
         and estado = 'G';
            EXCEPTION
              when v_no_procesar then
                raise v_no_procesar;
              when others then
                 pao_mor.pr_ins_informe( c_nom_proceso,
                                        c_fec_ini,
                                        'No se pudo actualizar el estado para el cliente ' || c.cod_persona ||
                                        ', Cuenta ' || c.ide_operacion || ', Relación ' || c.relacion );
            END;
            <<no_actualizar>>
            NULL;
          END LOOP;
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  '*** Proceso finalizado a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs. ***', FALSE );
   ELSE -- si existen registros en co_inf_procesos no corre el proceso
     if g_reproceso = 'N' then
       v_mensaje := 'Atencion: Ya se han generado los archivos de Informconf del dia de hoy '||to_char(v_hora_generado,'DD/MM/YYYY')|| ' a las '||to_char(v_hora_generado,'HH24:mi:ss')|| ' hs, Favor detener el proceso seleccionando el boton NO en el cuadro de diálogo. ' || v_men_error;
       raise v_error;
      end if;
   END IF;
EXCEPTION
  when v_error then
    RAISE_APPLICATION_ERROR( -20542, v_mensaje );
  when v_no_procesar then
    pao_mor.pr_ins_informe( c_nom_proceso,
                            c_fec_ini,
                            'NO SE HA EJECUTADO EL PROCESO DE CONFIRMACIÓN!!!!', FALSE );
  when others then
    pao_mor.pr_ins_informe( c_nom_proceso,
                            c_fec_ini,
                            'Se produjo un error en el proceso' );
END PR_PRO_INF_CONFIRMAR;
/* Indica que no existen registros sin procesar que impidan la ejecución de nuevos procesos */
FUNCTION FU_PUE_PROCESAR( p_fec_proceso IN DATE ) RETURN BOOLEAN IS
  v_ult_proceso DATE;
  v_tot_regs    NUMBER := 0;
  v_err_regs    NUMBER := 0;
  c_fec_ini     CONSTANT DATE := sysdate;
BEGIN
  BEGIN
    select max( fec_proceso )
      into v_ult_proceso
      from co_inf_ope_diarias
     where fec_proceso <= trunc( p_fec_proceso ) - 5;
  EXCEPTION
    when others then
      v_ult_proceso := trunc( p_fec_proceso );
  END;
  BEGIN
    select count(*), count( decode( nvl( estado, 'P' ), 'E', 1, NULL ) )
      into v_tot_regs, v_err_regs
      from co_inf_ope_diarias
     where fec_proceso = v_ult_proceso;
  EXCEPTION
    when others then
      v_tot_regs := 0;
      v_err_regs := 0;
      pao_mor.pr_ins_informe( 'FU_PUE_PROCESAR',
                              c_fec_ini,
                              'No se pudo verificar la cantidad de registros del día ' ||
                              to_char( v_ult_proceso, 'DD/MM/YYYY' ) );
  END;
  IF nvl( v_tot_regs, 0 ) > 0 AND
     nvl( v_tot_regs, 0 ) = nvl( v_err_regs, 0 ) THEN
    return FALSE;
  ELSE
    return TRUE;
  END IF;
END FU_PUE_PROCESAR;
/* Envío total de clientes a Control de Cartera en Informconf */

PROCEDURE PR_PRO_INF_CTL_CARTERA( P_FEC_PROCESO IN DATE DEFAULT trunc(pag_cal.fu_obt_fec_actual(6) ) ) IS
  c_tip_implement CONSTANT NUMBER(3) := fug_obt_tip_implementacion;
  v_nom_archivo   VARCHAR2(100);
  v_archivo       UTL_FILE.FILE_TYPE;
  v_min_cuota     CO_PAR_PROCESOS.CCT_MIN_CUO_PENDIENTE%TYPE;
  v_min_saldo_gs  CO_PAR_PROCESOS.CCT_MIN_SALDO_GS%TYPE;
  v_min_saldo_usd CO_PAR_PROCESOS.CCT_MIN_SALDO_USD%TYPE;
  v_dia_control   CO_PAR_PROCESOS.CCT_DIA_CONTROL%TYPE;
  v_usuario       CO_PAR_PROCESOS.CCT_USU_AUTORIZADO%TYPE;
  v_buffer        VARCHAR2(4000);
  c_fec_ini       CONSTANT DATE := sysdate;
  v_cedula        VARCHAR2(50);
  v_es_ci         NUMBER;
  /*
  || Este cursor es la baja de clientes.
  || Está compuesto por todos los registros que estaban en Informconf, y que ahora
  || no cumplen con los criterios necesarios para estar incluídos, normalmente es por
  || cancelación de préstamo, o por pagar todo el saldo de sus tarjetas.
  */
  CURSOR bajas
      IS select a.cod_cliente cod_persona, decode( p.tipo, 'F', f.pri_nombre, j.raz_social ) pri_nombre, f.seg_nombre,
                f.pri_apellido, f.seg_apellido,
                decode( nvl( f.cod_sexo, 'M' ), 'M', NULL, pao_mor.fu_obt_ape_casada( f.cod_persona ) ) ape_casada,
                f.fec_nacimiento,
                fuo_set_documento( p.cod_tip_documento, p.nro_documento ) nro_documento
           from co_inf_ctl_cartera a, ba_personas p, ba_per_fisicas f, ba_per_juridicas j
          where a.controlado = 'S'
            and a.cod_cliente = p.cod_persona
            and j.cod_persona(+) = p.cod_persona
            and f.cod_persona(+) = p.cod_persona
            and NOT EXISTS( select 1
                              from ( select c.cod_persona, g.cod_moneda, nvl( count(*), 0 ) can_cuo_pendiente,
                                            sum( nvl( r.sal_capital, 0 ) +
                                                 nvl( r.sal_interes, 0 ) +
                                                 nvl( r.sal_int_documentado, 0 ) ) sal_cuenta
                                       from ge_clientes c, ba_personas p, ba_per_fisicas f, ba_per_juridicas j,
                                            ge_cta_clientes t, pr_cta_prestamos g, pr_cuotas r, ba_per_dat_adicionales a
                                      where c.cod_persona IS NOT NULL
                                        and c.cod_persona = p.cod_persona
                                        and j.cod_persona(+) = p.cod_persona
                                        and f.cod_persona(+) = p.cod_persona
                                        and c.cod_persona = t.cod_persona
                                        and g.nro_cuenta = t.nro_cuenta
                                        and c.cod_persona= a.cod_persona
                                        and nvl( t.relacion, 'P' ) IN( 'P' )
                                        and nvl( g.estado, 'C' ) NOT IN( 'I', 'N' )
                                        and nvl( a.val_parametro, 'S' ) <> 'N'
                                        and g.nro_cuenta = r.nro_cuenta
                                        and r.nro_cuota > 0
                                        and nvl( r.estado, 'V' ) <> 'N'
                                        /*
                                        || Esto se agregó para que no envíe los Bonos del tesoro
                                        || y para Bríos que no envíe los bonos privados.
                                        */
                                        and g.cod_modalidad <> 650
                                        and ( c_tip_implement <> 2 OR
                                              ( c_tip_implement = 2 AND
                                                g.cod_modalidad <> 656 ) )
                                      group by c.cod_persona, g.cod_moneda
                                     having nvl( count(*), 0 ) >= nvl( v_min_cuota, 0 ) and
                                            sum( nvl( r.sal_capital, 0 ) +
                                                 nvl( r.sal_interes, 0 ) +
                                                 nvl( r.sal_int_documentado, 0 ) ) >= decode( g.cod_moneda, 'GS', nvl( v_min_saldo_gs, 0 ),
                                                                                                            'USD', nvl( v_min_saldo_usd, 0 ),
                                                                                                            0 )

                                   UNION
                                     select c.cod_persona, g.cod_moneda, 0 can_cuo_pendiente,
                                            sum( nvl( g.sal_facturar, 0 ) +
                                                 nvl( g.sal_facturado, 0 ) +
                                                 nvl( g.sal_financiado, 0 ) +
                                                 nvl( g.sal_cuo_pendientes, 0 ) ) sal_cuenta
                                       from ge_clientes c, ba_personas p, ba_per_fisicas f, ba_per_juridicas j,
                                            ge_cta_clientes t, ta_cta_tarjetas g, ba_per_dat_adicionales a
                                      where c.cod_persona IS NOT NULL
                                        and c.cod_persona = p.cod_persona
                                        and j.cod_persona(+) = p.cod_persona
                                        and f.cod_persona(+) = p.cod_persona
                                        and c.cod_persona = t.cod_persona
                                        and g.nro_cuenta = t.nro_cuenta
                                        and c.cod_persona= a.cod_persona
                                        and nvl( t.relacion, 'P' ) IN( 'P' )
                                        and nvl( g.estado, 'C' ) IN( 'N', 'B' )
                                        and nvl( a.val_parametro, 'S' ) <> 'N'
                                      group by c.cod_persona, 0, g.cod_moneda
                                     having sum( nvl( g.sal_facturar, 0 ) +
                                                 nvl( g.sal_facturado, 0 ) +
                                                 nvl( g.sal_financiado, 0 ) +
                                                 nvl( g.sal_cuo_pendientes, 0 ) ) >= decode( g.cod_moneda, 'GS', nvl( v_min_saldo_gs, 0 ),
                                                                                                          'USD', nvl( v_min_saldo_usd, 0 ),
                                                                                                           0 ) )
                             where cod_persona = a.cod_cliente )
          order by to_number( a.cod_cliente );
  /*
  || Este cursor es la alta de clientes en Informconf.
  || Está compuesto por toda la cartera de cliente de la entidad, cuyas cuentas cumplan con los criterios
  || mínimos de inclusión (saldo mínimo, cantidad de cuotas pendientes, etc), y que todavía no hayan
  || sido informados a Informconf.
  */
  CURSOR altas
      IS select distinct cod_persona, pri_nombre, seg_nombre, pri_apellido, seg_apellido, ape_casada, fec_nacimiento,
                nro_documento
           from ( select c.cod_persona, decode( p.tipo, 'F', f.pri_nombre, j.raz_social ) pri_nombre, f.seg_nombre,
                         f.pri_apellido, f.seg_apellido,
                         decode( nvl( f.cod_sexo, 'M' ), 'M', NULL, pao_mor.fu_obt_ape_casada( f.cod_persona ) ) ape_casada,
                         g.cod_modulo,
                         nvl( count(*), 0 ) can_cuo_pendiente, f.fec_nacimiento, g.cod_moneda,
                         fuo_set_documento( p.cod_tip_documento, p.nro_documento ) nro_documento,
                         sum( nvl( r.sal_capital, 0 ) +
                              nvl( r.sal_interes, 0 ) +
                              nvl( r.sal_int_documentado, 0 ) ) sal_cuenta
                    from ge_clientes c, ba_personas p, ba_per_fisicas f, ba_per_juridicas j, ge_cta_clientes t,
                         pr_cta_prestamos g, pr_cuotas r, ba_per_dat_adicionales a
                   where c.cod_persona IS NOT NULL
                     and c.cod_persona = p.cod_persona
                     and j.cod_persona(+) = p.cod_persona
                     and f.cod_persona(+) = p.cod_persona
                     and c.cod_persona = t.cod_persona
                     and g.nro_cuenta = t.nro_cuenta
                     and c.cod_persona=a.cod_persona
                     and nvl( t.relacion, 'P' ) IN( 'P' )
                     and nvl( g.estado, 'C' ) NOT IN( 'I', 'N' )
                     and g.nro_cuenta = r.nro_cuenta
                     and r.nro_cuota > 0
                     and nvl( r.estado, 'V' ) <> 'N'
                     and nvl( a.val_parametro, 'S' ) <> 'N'
                     and NOT EXISTS( select 1
                                       from co_inf_ctl_cartera r
                                      where r.cod_cliente = c.cod_persona
                                        and nvl( r.error, 'N' ) = 'N'
                                        and nvl( r.controlado, 'N' ) = 'S' )
                     /*
                     || Esto se agregó para que no envíe los Bonos del tesoro
                     || y para Bríos que no envíe los bonos privados.
                     */
                     and g.cod_modalidad <> 650
                     and ( c_tip_implement <> 2 OR
                           ( c_tip_implement = 2 AND
                             g.cod_modalidad <> 656 ) )
                   group by c.cod_persona, decode( p.tipo, 'F', f.pri_nombre, j.raz_social ), f.seg_nombre,
                            f.pri_apellido, f.seg_apellido, NULL, g.cod_modulo, f.fec_nacimiento, g.cod_moneda,
                            fuo_set_documento( p.cod_tip_documento, p.nro_documento )
                  having nvl( count(*), 0 ) >= nvl( v_min_cuota, 0 ) and
                         sum( nvl( r.sal_capital, 0 ) +
                              nvl( r.sal_interes, 0 ) +
                              nvl( r.sal_int_documentado, 0 ) ) >= decode( g.cod_moneda, 'GS', nvl( v_min_saldo_gs, 0 ),
                                                                                         'USD', nvl( v_min_saldo_usd, 0 ),
                                                                                         0 )
                UNION
                  select c.cod_persona, decode( p.tipo, 'F', f.pri_nombre, j.raz_social ) pri_nombre, f.seg_nombre,
                         f.pri_apellido, f.seg_apellido,
                         decode( nvl( f.cod_sexo, 'M' ), 'M', NULL, pao_mor.fu_obt_ape_casada( f.cod_persona ) ) ape_casada,
                         g.cod_modulo, 0 can_cuo_pendiente,
                         f.fec_nacimiento, g.cod_moneda,
                         fuo_set_documento( p.cod_tip_documento, p.nro_documento ) nro_documento,
                         sum( nvl( g.sal_facturar, 0 ) +
                              nvl( g.sal_facturado, 0 ) +
                              nvl( g.sal_financiado, 0 ) +
                              nvl( g.sal_cuo_pendientes, 0 ) ) sal_cuenta
                    from ge_clientes c, ba_personas p, ba_per_fisicas f, ba_per_juridicas j, ge_cta_clientes t,
                         ta_cta_tarjetas g, ba_per_dat_adicionales a
                   where c.cod_persona IS NOT NULL
                     and c.cod_persona = p.cod_persona
                     and j.cod_persona(+) = p.cod_persona
                     and f.cod_persona(+) = p.cod_persona
                     and c.cod_persona = t.cod_persona
                     and g.nro_cuenta = t.nro_cuenta
                     and c.cod_persona=a.cod_persona
                     and nvl( t.relacion, 'P' ) IN( 'P' )
                     and nvl( g.estado, 'C' ) IN( 'N', 'B' )
                     and nvl( a.val_parametro, 'S' ) <> 'N'
                     and NOT EXISTS( select 1
                                       from co_inf_ctl_cartera r
                                      where r.cod_cliente = c.cod_persona
                                        and nvl( r.error, 'N' ) = 'N'
                                        and nvl( r.controlado, 'N' ) = 'S' )
                   group by c.cod_persona, decode( p.tipo, 'F', f.pri_nombre, j.raz_social ), f.seg_nombre,
                            f.pri_apellido, f.seg_apellido, NULL, g.cod_modulo, 0, f.fec_nacimiento, g.cod_moneda,
                            fuo_set_documento( p.cod_tip_documento, p.nro_documento )
                  having sum( nvl( g.sal_facturar, 0 ) +
                              nvl( g.sal_facturado, 0 ) +
                              nvl( g.sal_financiado, 0 ) +
                              nvl( g.sal_cuo_pendientes, 0 ) ) >= decode( g.cod_moneda, 'GS', nvl( v_min_saldo_gs, 0 ),
                                                                                        'USD', nvl( v_min_saldo_usd, 0 ),
                                                                                        0 ) )
          order by to_number( cod_persona );
BEGIN
  BEGIN
    select cct_min_cuo_pendiente, cct_min_saldo_gs, cct_min_saldo_usd, cct_dia_control,
           cct_usu_autorizado
      into v_min_cuota, v_min_saldo_gs, v_min_saldo_usd, v_dia_control, v_usuario
      from co_par_procesos;
  EXCEPTION
    when others then
      v_directorio := NULL;
      v_min_cuota := 0;
      v_min_saldo_gs := 0;
      v_min_saldo_usd := 0;
      v_dia_control := 9999;
      v_usuario := NULL;
  END;
  -- Crea el archivo para enviar a Informconf
  v_nom_archivo := 'cc' || lpad( to_char( v_afiliado ), 4, '0' ) ||
                   to_char( nvl( p_fec_proceso, sysdate ), 'YYYYMMDD' ) || '.txt';
  v_archivo   := utl_file.fopen(v_directorio,v_nom_archivo,'w');
  -- Inicializa las variables
  v_cedula       := NULL;
  v_es_ci        := 0;
  v_buffer       := NULL;
  FOR x IN bajas LOOP
    v_es_ci := 0;
    BEGIN
      v_es_ci := nvl( to_number( x.nro_documento ), 0 );
    EXCEPTION
      when others then
        v_es_ci := 0;
    END;
    IF nvl( v_es_ci, 0 ) > 0 THEN
      v_cedula := ( replace( to_char( to_number( x.nro_documento ), '999,999,999,999'), ',', '.' ) );
    ELSE
      v_cedula := x.nro_documento;
    END IF;
    v_buffer := lpad( to_char( nvl( v_afiliado, 0 ) ), 6, '0' ) ||
                lpad( nvl( to_char( p_fec_proceso, 'YYYYMMDD' ), ' ' ), 8, ' ' ) ||
                rpad( nvl( substr( ltrim( rtrim( v_cedula ) ), 1, 15 ), ' ' ), 15, ' ' ) ||
                rpad( nvl( substr( x.pri_nombre, 1, 65 ), ' ' ), 65, ' ' ) ||
                rpad( nvl( substr( x.seg_nombre, 1, 20 ), ' ' ), 20, ' ' ) ||
                rpad( nvl( substr( x.pri_apellido, 1, 20 ), ' ' ), 20, ' ' );
    IF x.ape_casada IS NULL THEN
      v_buffer := v_buffer || rpad( nvl( substr( x.seg_apellido, 1, 20 ), ' ' ), 20, ' ' );
    ELSE
      v_buffer := v_buffer || rpad( ' ', 20, ' ' );
    END IF;
    v_buffer := v_buffer ||
                rpad( nvl( substr( x.ape_casada, 1, 20 ), ' ' ), 20, ' ' ) ||
                lpad( nvl( to_char( x.fec_nacimiento,'YYYYMMDD' ), '0' ), 8, '0' ) ||
                '0000' ||
                rpad( nvl( substr( v_usuario, 1, 45 ), ' ' ), 45, ' ' );
    utl_file.put_line(v_archivo,v_buffer);
    BEGIN
      update co_inf_ctl_cartera
         set controlado = 'N',
             fec_ult_salida = trunc( p_fec_proceso )
       where cod_cliente = x.cod_persona;
    EXCEPTION
      when others then
        pao_mor.pr_ins_informe( 'PR_PRO_INF_CTL_CARTERA',
                                c_fec_ini,
                                'No se pudo actualizar el registro de BAJA para el cliente ' || x.cod_persona );
    END;
  END LOOP;
  -- Inicializa las variables
  v_cedula       := NULL;
  v_es_ci        := 0;
  v_buffer       := NULL;
  FOR x IN altas LOOP
    v_es_ci := 0;
    BEGIN
      v_es_ci := nvl( to_number( x.nro_documento ), 0 );
    EXCEPTION
      when others then
        v_es_ci := 0;
    END;
    IF nvl( v_es_ci, 0 ) > 0 THEN
      v_cedula := ( replace( to_char( to_number( x.nro_documento ), '999,999,999,999'), ',', '.' ) );
    ELSE
      v_cedula := x.nro_documento;
    END IF;
    v_buffer := lpad( to_char( nvl( v_afiliado, 0 ) ), 6, '0' ) ||
                lpad( nvl( to_char( p_fec_proceso, 'YYYYMMDD' ), ' ' ), 8, ' ' ) ||
                rpad( nvl( substr( ltrim( rtrim( v_cedula ) ), 1, 15 ), ' ' ), 15, ' ' ) ||
                rpad( nvl( substr( x.pri_nombre, 1, 65 ), ' ' ), 65, ' ' ) ||
                rpad( nvl( substr( x.seg_nombre, 1, 20 ), ' ' ), 20, ' ' ) ||
                rpad( nvl( substr( x.pri_apellido, 1, 20 ), ' ' ), 20, ' ' );
    IF x.ape_casada IS NULL THEN
      v_buffer := v_buffer || rpad( nvl( substr( x.seg_apellido, 1, 20 ), ' ' ), 20, ' ' );
    ELSE
      v_buffer := v_buffer || rpad( ' ', 20, ' ' );
    END IF;
    v_buffer := v_buffer ||
                rpad( nvl( substr( x.ape_casada, 1, 20 ), ' ' ), 20, ' ' ) ||
                lpad( nvl( to_char( x.fec_nacimiento,'YYYYMMDD' ), '0' ), 8, '0' ) ||
                lpad( nvl( to_char( v_dia_control ), ' ' ), 4, '0' ) ||
                rpad( nvl( substr( v_usuario, 1, 45 ), ' ' ), 45, ' ' );
    utl_file.put_line(v_archivo,v_buffer);
    BEGIN
      update co_inf_ctl_cartera
         set controlado = 'S',
             fec_ult_ingreso = trunc( p_fec_proceso )
       where cod_cliente = x.cod_persona;
      IF sql%notfound THEN
        BEGIN
          insert into co_inf_ctl_cartera( cod_cliente,
                                          controlado,
                                          fec_ult_ingreso,
                                          fec_ult_salida,
                                          error )
                                  values( x.cod_persona,
                                          'S',
                                          trunc( p_fec_proceso ),
                                          NULL,
                                          'N' );
        EXCEPTION
          when others then
            pao_mor.pr_ins_informe( 'PR_PRO_INF_CTL_CARTERA',
                                    c_fec_ini,
                                    'No se pudo insertar el registro de ALTA para el cliente ' ||
                                    x.cod_persona );
        END;
      END IF;
    EXCEPTION
      when others then
        pao_mor.pr_ins_informe( 'PR_PRO_INF_CTL_CARTERA',
                                c_fec_ini,
                                'No se pudo actualizar el registro de ALTA para el cliente ' || x.cod_persona );
    END;
  END LOOP;
  utl_file.fclose(v_archivo);
EXCEPTION
  when others then
    utl_file.fclose(v_archivo);
    RAISE_APPLICATION_ERROR( -20511, 'PR_PRO_INF_CTL_CARTERA: Archivo ' || v_nom_archivo || ': ' || sqlerrm );
END PR_PRO_INF_CTL_CARTERA;
/* Verifica que no se hayan producido errores en los procesos de Informconf */
PROCEDURE PR_CTL_INF_PROCESO(P_FEC_PROCESO IN DATE DEFAULT trunc(sysdate)) IS
  v_contador            NUMBER;
  v_fec_actual          date := trunc(pag_cal.fu_obt_fec_actual(6));
  v_det_can_estados     varchar2(400) := null;
  
Cursor c_ope_estados is 
  select decode(p.estado,
                'E',
                'Errores',
                'G',
                'Generados',
                'P',
                'Procesados',
                'R',
                'Confirmados') estado,
         count(*) cantidad
    from co_inf_ope_diarias p
   where p.fec_proceso = v_fec_actual
     and p.estado <> 'R'
   group by p.estado;

BEGIN
       FOR c_est IN c_ope_estados LOOP  
       
       v_det_can_estados := ' '||c_est.estado ||' : '||c_est.cantidad;
         
       END LOOP;


          BEGIN
            select count(*)
              into v_contador
              from co_inf_procesos
             where comentario NOT LIKE '***%***'
               and trunc(fec_ini) = p_fec_proceso;
          EXCEPTION
            when others then
              v_contador := 0;
          END;
          IF nvl( v_contador, 0 ) > 0 and v_det_can_estados is not null THEN
            RAISE_APPLICATION_ERROR( -20000, 'Se produjeron errores en el proceso de Informconf. Verifique la tabla de logs.' ||' '||v_det_can_estados);
          END IF;

    EXCEPTION
          when others then
            IF sqlcode <= -20000 THEN
              RAISE;
            ELSE
              RAISE_APPLICATION_ERROR( -20001, 'ERROR. Al verificar la tabla de logs '||' '||v_det_can_estados || sqlerrm );
            END IF;

   END PR_CTL_INF_PROCESO;
    /* Obtiene el apellido de casada */
   FUNCTION FU_OBT_APE_CASADA( P_COD_PERSONA IN VARCHAR2 ) RETURN VARCHAR2 IS
      v_apellido BA_PER_FISICAS.PRI_APELLIDO%TYPE := NULL;
   BEGIN
          select pri_apellido
            into v_apellido
            from ba_per_fisicas a, ba_vinculos b
           where a.cod_persona = b.cod_per_vinculo
             and b.cod_persona = p_cod_persona
             and b.tipo = 'E'
             and rownum = 1;
          return v_apellido;
   EXCEPTION
          when no_data_found then
            return v_apellido;
          when others then
            return NULL;
   END FU_OBT_APE_CASADA;
   
PROCEDURE PR_ENV_MOROSIDAD (p_reproceso   varchar2 default 'N',
                            p_fec_proceso date default null )IS
  
  c_nom_proceso     CONSTANT VARCHAR2(30) := 'PR_ENV_MOROSIDAD';
  v_con_errores     number := 0;
  v_fec_proceso      date :=  trunc( pag_cal.fu_obt_fec_actual(6) );
  c_fec_actual      CONSTANT DATE := trunc( pag_cal.fu_obt_fec_actual(6) ); -- Fecha del módulo de Cobranzas  
  c_fec_ini         CONSTANT DATE := trunc(sysdate);
  v_mensaje         VARCHAR2(2000);
  v_men_error       CO_INF_PROCESOS.COMENTARIO%TYPE;
  v_proceso         varchar2(20);
  v_cont_pendientes NUMBER;
  v_cont_generados  NUMBER; 
  v_error           EXCEPTION;
BEGIN  
  begin
       Select 'S', t.fec_ini into v_exi_error ,v_hora_generado
         from co_inf_procesos t
        where trunc(t.fec_ini) = trunc(c_fec_ini)
          and lower(t.comentario) like lower('%El%proceso%Informconf culmin%satisfactoriamente%')
          and rownum = 1
          and nvl(p_reproceso,'N') = 'N';
       --Verificar si ya existen registros de la fecha en co_inf_procesos
  exception
     when others then
       v_exi_error:='N';
  end;
  If p_reproceso = 'S' then
    v_proceso   := ' Reproceso ';  
    g_reproceso := 'S';
  else
    v_proceso := ' Proceso ';
  End if;
  IF v_exi_error='N' or p_reproceso = 'S' then -- Si no existen registros en co_inf_procesos corre el proceso 

       pao_mor.pr_gen_inf_archivo( trunc( v_fec_proceso ) );
        -- Inserta registro del proceso.
        IF nvl( v_con_errores, 0 ) = 0 THEN
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  '*** El'||v_proceso||' de interface de Informconf culmino satisfactoriamente a las ' || to_char( sysdate, 'HH24:MI:SS' ) || ' Hs.! ***',
                                  FALSE );
        ELSE
          pao_mor.pr_ins_informe( c_nom_proceso,
                                  c_fec_ini,
                                  'El'||v_proceso||'de interface de Informconf culmino con ' || to_char( v_con_errores ) ||
                                  ' error(es).',
                                  FALSE );
        END IF;
        
  ELSE -- si existen registros en co_inf_procesos no corre el proceso
      v_mensaje := 'Atencion: Ya se han generado los archivos de Informconf del dia de hoy '||to_char(v_hora_generado,'DD/MM/YYYY')|| ' a las '||to_char(v_hora_generado,'HH24:mi:ss')|| ' hs, Favor detener el proceso seleccionando el boton NO en el cuadro de diálogo. ' || v_men_error;
      raise v_error;
  END IF;
  If g_reproceso = 'S' then
     PAO_MOR.PR_PRO_INF_CONFIRMAR(v_fec_proceso);
  End if;
exception
when v_error then
    RAISE_APPLICATION_ERROR( -20542, v_mensaje );
END;   

PROCEDURE PR_INS_INF_HISTORICO (p_cod_persona    co_inf_personas.cod_persona%type,
                                p_ide_operacion  co_inf_personas.ide_operacion%type,
                                p_relacion       co_inf_personas.relacion%type,
                                p_fec_proceso    date) IS 

c_nom_proceso CONSTANT VARCHAR2(30) := 'PR_INS_INF_HISTORICO';
c_fec_ini     CONSTANT DATE := sysdate;
rg_inpe              co_inf_personas%rowtype;
v_exi_historico      varchar2(1) := 'N';

PRAGMA AUTONOMOUS_TRANSACTION;  

BEGIN
   begin
    select *
      into rg_inpe
      from co_inf_personas p
     where p.cod_persona = p_cod_persona
       and p.ide_operacion = p_ide_operacion
       and p.relacion = p_relacion;
    exception
      when no_data_found then
        null;
      when others then
        null;
    end;
  
    begin
     select distinct 'S'
      into v_exi_historico
      from co_inf_personas_his p
     where p.cod_persona = p_cod_persona
       and p.ide_operacion = p_ide_operacion
       and p.relacion = p_relacion
       and p.fec_historico = p_fec_proceso;   
    exception
      when no_data_found then
        v_exi_historico := 'N';
      when others then
        v_exi_historico := 'N';
    end;
    
    if nvl(rg_inpe.ide_operacion,'X') <> 'X' and nvl(v_exi_historico,'N') = 'N' then
      
       begin
                insert into CO_INF_PERSONAS_HIS(
                                             fec_historico,
                                             cod_persona,
                                             cod_modulo,
                                             cod_modalidad,
                                             cod_moneda,
                                             relacion,
                                             cod_afiliado,
                                             fec_informacion,
                                             nro_documento,
                                             pri_nombre,
                                             seg_nombre,
                                             pri_apellido,
                                             seg_apellido,
                                             ape_casada,
                                             fec_operacion,
                                             ide_operacion,
                                             cod_inf_operacion,
                                             mto_operacion,
                                             cod_inf_moneda,
                                             pla_operacion,
                                             fec_ven_pendiente,
                                             fec_ult_pago,
                                             saldo )
                                     values( p_fec_proceso,
                                             rg_inpe.cod_persona,
                                             rg_inpe.cod_modulo,
                                             rg_inpe.cod_modalidad,
                                             rg_inpe.cod_moneda,
                                             rg_inpe.relacion,
                                             rg_inpe.cod_afiliado,
                                             rg_inpe.fec_informacion,
                                             rg_inpe.nro_documento,
                                             rg_inpe.pri_nombre,
                                             rg_inpe.seg_nombre,
                                             rg_inpe.pri_apellido,
                                             rg_inpe.seg_apellido,
                                             rg_inpe.ape_casada,
                                             rg_inpe.fec_operacion,
                                             rg_inpe.ide_operacion,
                                             rg_inpe.cod_inf_operacion,
                                             rg_inpe.mto_operacion,
                                             rg_inpe.cod_inf_moneda,
                                             rg_inpe.pla_operacion,
                                             rg_inpe.fec_ven_pendiente,
                                             rg_inpe.fec_ult_pago,
                                             rg_inpe.saldo );
        commit;
        exception
             when others then
                    pao_mor.pr_ins_informe( c_nom_proceso,
                                            c_fec_ini,
                                            'No se pudo actualizar historico cliente ' || rg_inpe.cod_persona ||
                                            ', Cuenta ' || rg_inpe.ide_operacion || ', Relación ' || rg_inpe.relacion );

        end;
      End if;                                                                      
END;                                              
PROCEDURE PR_NOT_PROCESAMIENTO (P_FEC_PROCESO IN DATE DEFAULT null) IS

  v_fec_proceso  date := nvl(P_FEC_PROCESO, trunc(pag_cal.fu_obt_fec_actual(6)));

Cursor c_procesados is 
 select decode(p.estado,'E','Errores','G','Generados','P','Procesados','R','Confirmados') estado, count(*) cantidad
      from co_inf_ope_diarias p
     where p.fec_proceso = v_fec_proceso
     group by p.estado;
     
cursor c_tipo is
 select decode(p.fin_registro,'E','Eliminaciones','I','Inclusiones') tipo, count(*) cantidad
      from co_inf_ope_diarias p
     where p.fec_proceso = v_fec_proceso
     group by p.fin_registro;    

  v_msj_titulo     varchar2(80)  := 'Proceso Automatico de INFORMCONF del '||trunc(v_fec_proceso);
  v_mje_mail       LONG;
  v_conn           utl_smtp.connection;
  v_texto          varchar2(5000);
  v_texto_detalle  varchar2(32000) := null;
  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := fug_gen_template('P');
  v_det_estados    varchar2(2000);
 
  v_dir_envio      ge_par_dinamicos.val_parametro%type := FUG_OBT_PARDINAMICO('MAI_USU_INFORMCONF');
  v_remitente     ge_par_generales.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo;

begin
FOR reg IN c_procesados LOOP
  v_det_estados := v_det_estados ||' '||reg.estado ||': '||reg.cantidad||' ';
END LOOP;

FOR i in c_tipo LOOP
  v_det_estados := v_det_estados ||'<br>'|| i.tipo ||': '||i.cantidad;
END LOOP;  
             v_texto := '<br><br>
                         <br><br>
                         <br><br>
                           Resumen de la ejecuci&oacute;n del proceso de INFORMCONF de fecha ' ||
                                   v_fec_proceso || '.
                         <br><br>
                           Detalles: '||v_det_estados||'
                         <br><br>
                         <br><br>';
              v_mje_mail := v_membrete||v_texto||V_FIN||V_PIE;
             BEGIN
               v_conn     := it_mail.begin_mail(v_remitente,
                                                 v_dir_envio,
                                                 v_msj_titulo,
                                                 IT_MAIL.MULTIPART_MIME_TYPE);
                it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                it_mail.write_text(v_conn, v_texto_detalle);
                it_mail.end_mail(v_conn);
              EXCEPTION
               
  when others then
                      v_texto := SQLERRM;
                      insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                      values (v_remitente, v_dir_envio, v_msj_titulo, v_texto, sysdate, user)  ;

              end;


  end;                                              

PROCEDURE PR_PRO_AUTOMATICO IS
  
 c_nom_proceso         CONSTANT VARCHAR2(30) := 'PR_PRO_AUTOMATICO'; 
 v_can_int_configurado ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_INT_ENV_MOROSIDAD');
 v_can_intentos        number := 0;   
Begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:= 1; end;
  ---Generación de Información a enviar
  IF NOT FUE_CTR_FEC_FERIADO(trunc(sysdate), null) then -- si es feriado no debe ejecutar
    begin
      PAO_MOR.PR_PRO_INF_DIARIO;
      commit;
    exception
      when others then
        pao_mor.pr_ins_informe(c_nom_proceso, sysdate,
                               'PAO_MOR.PR_PRO_INF_DIARIO Error al ejecutar Proceso Automático');
    end;


    --Procesamiento de Envio de datos a Informconf
    begin
      PAO_MOR.PR_ENV_MOROSIDAD;
      commit;
    exception
      when others then
        pao_mor.pr_ins_informe(c_nom_proceso, sysdate,
                               'PAO_MOR.PR_ENV_MOROSIDAD Error al realizar envío Automatico ');
    end;

    --Proceso de Confirmación de Envios Correctos
    begin
      PAO_MOR.PR_PRO_INF_CONFIRMAR;
      commit;
    exception
      when others then
        pao_mor.pr_ins_informe(c_nom_proceso, sysdate,
                               'PAO_MOR.PR_PRO_INF_CONFIRMAR No se pudo confirmar registros correctos ');
    end;
    -- en caso que se hayan quedado registros con errores, vuelve a reintentar el envio
    begin
      If g_reauto = 'S' Then
         WHILE v_can_intentos <= v_can_int_configurado LOOP
          v_can_intentos := v_can_intentos + 1;
          --Reenvio Automatico
          PAO_MOR.PR_ENV_MOROSIDAD('S');
         END LOOP;
      End if;
    exception
      when others then
        pao_mor.pr_ins_informe(c_nom_proceso,
                               sysdate,
                               'PAO_MOR.PR_ENV_MOROSIDAD No se pudo realizar REENVIO AUTOMATICO');
    end;
    -- notificacion del procesamiento
    begin
      PAO_MOR.PR_NOT_PROCESAMIENTO;
    
      commit;
    exception
      when others then
        pao_mor.pr_ins_informe(c_nom_proceso,
                               sysdate,
                               'PAO_MOR.PR_NOT_PROCESAMIENTO No se pudo actualizar historico cliente ');
    end;
  end if;
 
end;

END PAO_MOR;
/
