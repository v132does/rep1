CREATE OR REPLACE PROCEDURE IT.PRL_GEN_OPE_EFECTIVOS IS
  v_msj     varchar2(250);
  v_fecha   date;   
  v_max_dia_anterior number := fug_obt_pardinamico('MAX_DIA_ANT_OPE_EFECTIVO');
  v_tabla   varchar2(60);
  type typ_cursor is ref cursor;
  c_cursor  typ_cursor;
  v_fec_movimiento      ge_movimientos.fecha%type;
  v_hora                ge_movimientos.hora%type;
  v_cod_usuario         ge_movimientos.cod_usuario%type;
  v_cod_transaccion     ge_movimientos.cod_transaccion%type;
  v_cod_modulo          ge_movimientos.cod_modulo%type;
  v_cod_modalidad       ge_movimientos.cod_modalidad%type;
  v_nro_cuenta          ge_movimientos.nro_cuenta%type;
  v_cod_persona         ba_personas.cod_persona%type;
  v_monto               ge_movimientos.monto%type;
  v_cotizacion          ge_movimientos.cotizacion%type;
  v_concepto            ge_movimientos.concepto%type;
  v_estado              ge_movimientos.estado%type;
  v_cod_moneda          ge_movimientos.cod_moneda%type;
  v_cod_gru_transaccion ge_gru_transacciones_det.cod_gru_transaccion%type;
  v_cod_ofi_origen      ge_movimientos.cod_ofi_origen%type;
  v_sentencia           long;
BEGIN
  execute immediate 'Alter session set nls_date_format = ''DD/MM/YYYY''';
  
  sql_util.ejecute_dml('TRUNCATE TABLE LC_OPE_EFECTIVOS', v_msj);
  
  IF v_msj IS NOT NULL THEN
    raise_application_error(-20000, v_msj);
  END IF;
  
  v_fecha := to_date(fug_obt_pardinamico('FEC_OPE_EFE_DESDE'),'dd/mm/yyyy');

  if pag_cal.fu_obt_fec_actual(1) - v_fecha > v_max_dia_anterior then
    v_fecha := pag_cal.fu_obt_fec_actual(1) - v_max_dia_anterior;
  end if;

  if v_fecha = pag_cal.fu_obt_fec_anterior(1) then
    v_tabla := 'ge_movimientos_ant';
  elsif v_fecha < pag_cal.fu_obt_fec_anterior(1) then
    v_tabla := 'gv_movimientos';
  elsif v_fecha = pag_cal.fu_obt_fec_actual(1) then
    v_tabla := 'ge_movimientos';
  end if;

  v_sentencia := 'select fecha, hora, cod_usuario, a.cod_transaccion, a.cod_modulo, a.cod_modalidad, '||
                 'nro_cuenta, cod_persona, monto, cotizacion, concepto, estado, a.cod_moneda, '||
                 'd.cod_gru_transaccion, a.cod_ofi_origen from '
                 ||v_tabla||
                 ' a, ge_gru_transacciones_det d where a.fecha >= '
                 ||'to_date('''||v_fecha||''',''dd/mm/yyyy'')'||
                 ' and a.cod_transaccion = d.cod_transaccion and a.cod_modulo = d.cod_modulo '||
                 'and a.cod_modalidad = d.cod_modalidad and d.cod_gru_transaccion in (71, 72, 73, 74, 75, 76, 77, 78) '||
                 'and a.reversado = ''N'' and a.estado = ''N''';

  if v_tabla = 'ge_movimientos_ant' then
    v_sentencia := v_sentencia||' union '|| replace(v_sentencia,'ge_movimientos_ant', 'ge_movimientos');
  end if;

  OPEN c_cursor FOR v_sentencia;
  loop fetch c_cursor into
    v_fec_movimiento, v_hora, v_cod_usuario, v_cod_transaccion,
    v_cod_modulo, v_cod_modalidad, v_nro_cuenta, v_cod_persona,
    v_monto, v_cotizacion, v_concepto, v_estado, v_cod_moneda,
    v_cod_gru_transaccion, v_cod_ofi_origen;

    exit when c_cursor%notfound;

    insert into lc_ope_efectivos
      (fecha,
       hora,
       cod_usuario,
       cod_transaccion,
       cod_modulo,
       cod_modalidad,
       nro_cuenta,
       cod_persona,
       monto,
       cotizacion,
       concepto,
       estado,       cod_moneda,
       cod_tip_ope_efe,
       cod_ofi_origen)
    values
      (v_fec_movimiento,
       v_hora,
       v_cod_usuario,
       v_cod_transaccion,
       v_cod_modulo,
       v_cod_modalidad,
       v_nro_cuenta,
       v_cod_persona,
       nvl(v_monto, 0),
       v_cotizacion,
       v_concepto,
       'N',
       v_cod_moneda,
       substr(v_cod_gru_transaccion,2,1),
       v_cod_ofi_origen);
  END LOOP;
  -- Se actualiza el parámetro para la próxima ejecución.
  update ge_par_dinamicos a
  set a.val_parametro = to_char(pag_cal.fu_obt_fec_actual(1),'dd/mm/yyyy')
  where a.parametro = 'FEC_OPE_EFE_DESDE';

EXCEPTION
  when others then
    raise_application_error(-20000, 'Error ' || SQLERRM);
END;
/

