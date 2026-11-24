create or replace procedure it.prb_act_not_credito(p_tip_actualizacion in varchar2 default null,
                                                   p_fecha in date default null,
                                                   p_hora in varchar2 default null,
                                                   p_cod_usuario in varchar2 default null,
                                                   p_nro_secuencia in number default null,
                                                   p_nro_factura in varchar2 default null,
                                                   p_nro_timbrado in varchar2 default null,
                                                   p_fec_mov in date default null,
                                                   p_hor_mov in varchar2 default null,
                                                   p_cod_usu_mov in varchar2 default null,
                                                   p_nro_sec_mov in number default null) is

  --Proyecto SDDEC312NC-6--
  --Notas de Credito de Tarjetas de Credito--
  --Proceso de actualizacion automatica de NRO_FACTURA--

  --Variables--
  v_nro_factura cb_lib_ventas.nro_factura%type;
  v_nro_timbrado cb_lib_ventas.nro_timbrado%type;
  v_nro_referencia cb_lib_ventas_det_tmp.rel_fac_referencia%type;
  v_fec_actual date;
  v_fec_ini_mes date;
  v_fec_fin_mes date;
  v_ult_dia_mes_habil date;

  --Cursor Notas de Credito c/ Factura (gENERAL)--
  cursor c_not_cre_sin_fac is
  select a.*, a.rowid registro
    from cb_lib_ventas_det_tmp a
   where a.reversado = 'S' --Notas de Credito--
     and a.nro_factura = '0'
     and a.rel_fac_referencia is null
     and exists (select 1
                   from ge_par_dinamicos x
                  where x.parametro = 'MOD_MAN_NOT_CREDITO'
                    and x.cod_modulo = a.cod_modulo
                    and x.val_parametro = 'S');

  --Cursor Notas de Credito del mismo mes (Solo TC)--
  cursor c_rev_tra_mes_tc is
  --Historico--
  select a.fecha, a.hora, a.cod_usuario,
         a.cod_tra_padre, a.cod_transaccion,
         a.nro_cuenta, a.monto, b.cod_persona
    from ta_movimientos_his a, ge_cta_clientes b
   where a.cod_tra_padre = 1216
     and a.cod_transaccion = 1600
     and a.reversado = 'N'
     and a.monto < 0 --Notas de Creditos--
     and a.fecha between v_fec_ini_mes and v_fec_fin_mes
     and b.nro_cuenta = a.nro_cuenta
     and b.relacion = 'P'
     and exists (select 1 from ta_movimientos_his x
                  where x.nro_cuenta = a.nro_cuenta
                    and x.cod_tra_padre = a.cod_tra_padre
                    and x.cod_transaccion = a.cod_transaccion
                    and x.reversado = 'N'
                    and x.monto > 0 --Facturas--
                    and x.monto = abs(a.monto)
                    and x.fecha < a.fecha)
  union
  --Diario--
  select a.fecha, a.hora, a.cod_usuario,
         a.cod_tra_padre, a.cod_transaccion,
         a.nro_cuenta, a.monto, b.cod_persona
    from ge_movimientos a, ge_cta_clientes b
   where a.cod_tra_padre = 1216
     and a.cod_transaccion = 1600
     and a.reversado = 'N'
     and a.monto < 0 --Notas de Creditos
     and a.fecha = v_fec_actual
     and b.nro_cuenta = a.nro_cuenta
     and b.relacion = 'P'
     and exists (select 1 from ta_movimientos_his x
                  where x.nro_cuenta = a.nro_cuenta
                    and x.cod_tra_padre = a.cod_tra_padre
                    and x.cod_transaccion = a.cod_transaccion
                    and x.reversado = 'N'
                    and x.monto > 0 --Facturas--
                    and x.monto = abs(a.monto)
                    and x.fecha < a.fecha);

  --Cursor Notas de Credito c/ Factura en mismo mes--
  cursor c_not_cre_fac_mes is
  select y.rel_fac_referencia
    from cb_lib_ventas_det_tmp y
   where y.rel_fac_referencia is not null
     and y.reversado = 'S'
     and exists (select 1
                   from cb_lib_ventas_det_tmp z
                  where z.rel_fac_referencia is not null
                    and z.reversado = 'N'
                    and z.rel_fac_referencia = y.rel_fac_referencia
                    and z.cod_persona = y.cod_persona);


begin
  -- Registrar el nombre en action
  DBMS_APPLICATION_INFO.SET_ACTION('PRB_ACT_NOT_CREDITO');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRB_ACT_NOT_CREDITO, Iniciando');
  --Carga de variables--
  pag_cal.PR_OBT_DAT_CALENDAR(5);
  v_fec_actual := pag_cal.G_FEC_ACTUAL;
  v_ult_dia_mes_habil := pag_cal.G_ULT_DIA_MES_HABIL;
  v_fec_ini_mes := to_date('01'||to_char(v_fec_actual,'/mm/yyyy'),'dd/mm/yyyy');
  v_fec_fin_mes := last_day(v_fec_actual);

  if nvl(p_tip_actualizacion,'X') = 'M' then --Por movimiento--
     --Actualiza temporal con Nro Factura y Timbrado recibido--
     if p_nro_factura = 'FAC_MES_A_GENERAR' then
        --Obtiene Nro de Referencia--
        SELECT s_nro_referencia.nextval
        INTO v_nro_referencia
        FROM dual;
        
        --Actualiza mov de Factura con referencia--
        update cb_lib_ventas_det_tmp a
           set a.rel_act_operativa = 'S',
               a.rel_fac_referencia = v_nro_referencia
         where a.fecha = p_fec_mov
           and a.hora = p_hor_mov
           and a.cod_usuario = p_cod_usu_mov
           and a.nro_secuencia = p_nro_sec_mov
           and nvl(a.reversado,'N') = 'N';
     else
        v_nro_referencia := null;
     end if;
     
     --Actualizar mov de Nota de Credito--
     update cb_lib_ventas_det_tmp a
        set a.nro_factura = p_nro_factura,
            a.nro_timbrado = p_nro_timbrado,
            a.rel_act_operativa = 'S',
            a.rel_fac_referencia = v_nro_referencia
      where a.fecha = p_fecha
        and a.hora = p_hora
        and a.cod_usuario = p_cod_usuario
        and a.nro_secuencia = p_nro_secuencia
        and a.nro_factura = '0'
        and a.reversado = 'S';
  else --Es nulo, actualizacion general--
  --Notas de Credito c/ Facturas ya generadas--
  for tmp in c_not_cre_sin_fac loop
    v_nro_factura := null;
    v_nro_timbrado := null;
    begin
      select x.nro_factura, x.nro_timbrado
        into v_nro_factura, v_nro_timbrado
        from cb_lib_ventas_det x, cb_lib_ventas y
       where y.nro_factura = x.nro_factura
         and y.nro_timbrado = x.nro_timbrado
         and y.tip_comprobante = 'F'
         and y.cod_persona = tmp.cod_persona
         and x.cod_tra_padre = tmp.cod_tra_padre
         and x.cod_transaccion = tmp.cod_transaccion
         and x.mto_gravado_10 = tmp.mto_gravado_10
         and x.fecha < tmp.fecha;
    exception
      when others then
           null;
    end;
    if v_nro_factura is not null then
       update cb_lib_ventas_det_tmp c
          set c.nro_factura = v_nro_factura,
              c.nro_timbrado = v_nro_timbrado
        where c.rowid = tmp.registro;
    end if;
  end loop;

  --Notas de Credito del mismo mes--
  for rev in c_rev_tra_mes_tc loop
      SELECT s_nro_referencia.nextval
        INTO v_nro_referencia
        FROM dual;

      --Registro de NC - Reversion--
      update cb_lib_ventas_det_tmp z
         set z.rel_fac_referencia = v_nro_referencia
       where z.cod_tra_padre = rev.cod_tra_padre
         and z.cod_tra_base = rev.cod_transaccion
         and z.mto_gravado_10 = abs(rev.monto)
         and z.fecha = rev.fecha
         and z.hora = rev.hora
         and z.cod_usuario = rev.cod_usuario
         and z.nro_cuenta = rev.nro_cuenta
         and z.cod_persona = rev.cod_persona
         and z.reversado = 'S'
         and z.rel_fac_referencia is null;

      --Registro de FAC - Movimiento--
      update cb_lib_ventas_det_tmp z
         set z.rel_fac_referencia = v_nro_referencia
       where z.cod_tra_padre = rev.cod_tra_padre
         and z.cod_tra_base = rev.cod_transaccion
         and z.mto_gravado_10 = abs(rev.monto)
         and z.fecha < rev.fecha
         and z.nro_cuenta = rev.nro_cuenta
         and z.cod_persona = rev.cod_persona
         and z.reversado = 'N'
         and z.rel_fac_referencia is null;
  end loop;

  --Si es fin de mes elimina reg de NC de TC mismo mes--
  if v_fec_actual = v_ult_dia_mes_habil then
    --Eliminacion de Nota de Credito y Factura del mismo mes--
    for mes in c_not_cre_fac_mes loop
        delete from cb_lib_ventas_det_tmp k
         where k.rel_fac_referencia = mes.rel_fac_referencia;
    end loop;
  end if;
  end if;
  -- Dejar null la acción para que no quede en memoria 
  DBMS_APPLICATION_INFO.SET_ACTION(NULL);
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
exception
  when others then
    -- Dejar null la acción para que no quede en memoria 
    DBMS_APPLICATION_INFO.SET_ACTION(NULL);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL); 
    raise_application_error(-20001,'Error en prb_act_not_credito: '||sqlerrm);
end;
/
