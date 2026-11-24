CREATE OR REPLACE PROCEDURE IT.PRG_PRO_INF_COB_BATCH(p_fecha date, p_nro_cuenta varchar2, p_eli_his varchar2 default 'N', p_tipo varchar default 'I' ) is
  /*  Procesa los movimientos liberado de infonet cobranzas. tiene 2 partes:
      1. procesa reversado movimientos del dia para contabilizar
      2. Procesa reversado movimientos luego de 48 Hs para el debito y credito respectivo
  */
  ---
  v_fec_actual   date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_cod_oficina  number(4) := fug_obt_ofi_matriz;
  v_nro_secuencia number(4);
  v_hora         varchar2(8);
  v_mto_credito  ge_movimientos.monto%type;
  v_con_mov_com_bancard ge_movimientos.concepto%type := fug_obt_pardinamico('CON_MOV_COM_BANCARD');
  v_fec_anterior date :=  pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha, 1);
  v_fec_ant_48 date;
  v_msj_error VARCHAR2(1000);
  v_nro_cta_credito ge_cuentas.nro_cuenta%type;
  v_hor_corte varchar2(8);
  v_cta_deb_icb cc_cta_ficticias.nro_cuenta%type := fug_obt_pardinamico('ICB_CTA_TRA_DEB');

  R_GMOVI GE_MOVIMIENTOS%ROWTYPE;

  --- recupera los datos dev_cod_oficina la cuenta ficticia
  procedure lp_obt_cta_ficticia(p_nro_cuenta      in ge_cuentas.nro_cuenta%type,
                                p_cod_modulo      out ge_cuentas.cod_modulo%type,
                                p_cod_modalidad   out ge_cuentas.cod_modalidad%type,
                                p_cod_rubro       out cb_rubros.cod_rubro%type,
                                p_ind_ficticia    out varchar2) is
  Begin
     select cod_modulo, cod_modalidad, cod_rubro, 'S'
       into p_cod_modulo, p_cod_modalidad, p_cod_rubro, p_ind_ficticia
       from cc_cta_ficticias
      where nro_cuenta = p_nro_cuenta;
  Exception
    WHEN NO_DATA_FOUND THEN
       p_ind_ficticia  := 'N';
  end;

  procedure lp_ins_log( p_nro_transaccion number, p_mto_facturador number, p_cod_moneda varchar2, p_mensaje varchar2, p_ind_mov_cierre varchar2 ) is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    insert into GE_LOG_INF_COB_BATCH (FECHA,Hora,COD_USUARIO,NRO_TRANSACCION,NRO_CUENTA,MTO_FACTURADOR,COD_MONEDA,DET_ERROR, IND_MOV_COMISION)
    values (p_fecha, v_hora, user, p_nro_transaccion, p_nro_cuenta, p_mto_facturador, p_cod_moneda, substr(p_mensaje, 1, 1000), p_ind_mov_cierre);
    commit;
  end lp_ins_log;


 procedure lp_eli_mov_adicionales is
    CURSOR cu_movimientos (p_fec_mov date)
        IS select t.fecha, t.hora, t.nro_secuencia, t.cod_usuario, t.hor_referencia,
                  t.fec_valor, t.cod_modulo, t.cod_modalidad, t.nro_cuenta, t.tip_operacion,
                  t.cod_tra_padre, t.cod_moneda, t.monto, t.mto_comision, t.cod_extorno,
                  t.nro_documento, t.nro_transaccion, t.dat_adicional, t.liberado, t.fec_acreditacion,
                  t.usu_insercion, t.fec_insercion, t.usu_modificacion, t.fec_modificacion, t.nro_cta_deb_batch
             from ge_mov_dat_adicionales t
            where fecha <= p_fec_mov;
    v_can_dia_mov_adi number := nvl(fug_obt_pardinamico('ICB_CAN_DIA_MOV_CTA_TRA'),5);
    v_fec_mov_adi date;
    v_det_error ge_mov_dat_adicionales_err.det_error%type;
    TYPE cursor1_type IS TABLE OF cu_movimientos%ROWTYPE;
    c cursor1_type;
  begin
    v_Fec_mov_adi := v_fec_actual - nvl(v_can_dia_mov_adi,5);
    OPEN cu_movimientos(v_fec_mov_adi);
    LOOP
    FETCH cu_movimientos BULK COLLECT INTO c LIMIT 3000;
    FOR i IN 1 .. c.count LOOP
      BEGIN
        insert into ge_mov_dat_adicionales_his ( fecha, hora, nro_secuencia, cod_usuario, hor_referencia,
                                                 fec_valor, cod_modulo, cod_modalidad, nro_cuenta, tip_operacion,
                                                 cod_tra_padre, cod_moneda, monto, mto_comision, cod_extorno,
                                                 nro_documento, nro_transaccion, dat_adicional, liberado, fec_acreditacion,
                                                 usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                                                 nro_cta_deb_batch)
                                          values ( c(i).fecha, c(i).hora, c(i).nro_secuencia, c(i).cod_usuario, c(i).hor_referencia,
                                                   c(i).fec_valor, c(i).cod_modulo, c(i).cod_modalidad, c(i).nro_cuenta, c(i).tip_operacion,
                                                   c(i).cod_tra_padre, c(i).cod_moneda, c(i).monto, c(i).mto_comision, c(i).cod_extorno,
                                                   c(i).nro_documento, c(i).nro_transaccion, c(i).dat_adicional, c(i).liberado, c(i).fec_acreditacion,
                                                   c(i).usu_insercion, c(i).fec_insercion, c(i).usu_modificacion, c(i).fec_modificacion,
                                                   c(i).nro_cta_deb_batch);

      EXCEPTION
        WHEN OTHERS THEN
          v_det_error := substr('Error al pasar al historico. '||sqlerrm,1,4000);
          insert into ge_mov_dat_adicionales_err ( fecha, hora, nro_secuencia, cod_usuario, hor_referencia,
                                                   fec_valor, cod_modulo, cod_modalidad, nro_cuenta, tip_operacion,
                                                   cod_tra_padre, cod_moneda, monto, mto_comision, cod_extorno,
                                                   nro_documento, nro_transaccion, dat_adicional, liberado, fec_acreditacion,
                                                   usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                                                   nro_cta_deb_batch,det_error)
                                          values ( c(i).fecha, c(i).hora, c(i).nro_secuencia, c(i).cod_usuario,c(i).hor_referencia,
                                                   c(i).fec_valor, c(i).cod_modulo, c(i).cod_modalidad, c(i).nro_cuenta, c(i).tip_operacion,
                                                   c(i).cod_tra_padre, c(i).cod_moneda, c(i).monto, c(i).mto_comision, c(i).cod_extorno,
                                                   c(i).nro_documento, c(i).nro_transaccion, c(i).dat_adicional, c(i).liberado, c(i).fec_acreditacion,
                                                   c(i).usu_insercion, c(i).fec_insercion, c(i).usu_modificacion, c(i).fec_modificacion,
                                                   c(i).nro_cta_deb_batch,v_det_error);
     END;
    END LOOP;
    commit;
    EXIT WHEN cu_movimientos%NOTFOUND;
    END LOOP;
    commit;
    begin
      delete from ge_mov_dat_adicionales
       where fecha <= v_fec_mov_adi;
      commit;
    exception
      when others then
         lp_ins_log( 0, 0, null, substr('No se pudo borrar los datos adicionales de movimientos. '||sqlerrm,1,4000), 'N');
    end;
  end ;

  procedure lp_ins_inf_cob_batch is
    CURSOR c_mov_batch IS
      SELECT i.nom_archivo, i.fecha, i.tip_registro, i.cod_emision, i.cod_sucursal, i.cod_caja,
             i.dig_ver_cod_barra, i.monto, i.mto_facturador, to_date(i.fec_cobro,'dd/mm/yyyy') fec_cobro, i.nro_documento, i.cod_cargo,
             i.nro_factura, i.cod_entidad, i.nro_transaccion, i.cod_tra_padre, i.hor_referencia, i.dat_adicional,
             i.incluir, i.nro_cta_deb_batch
        FROM ge_inf_cob_batch_tmp i
       WHERE fecha = p_fecha;
     v_nro_proceso ge_inf_cob_batch.nro_proceso%type;
     v_nro_cuenta ge_cuentas.nro_cuenta%type;
     v_cod_rubro cb_rubros.cod_rubro%type;
  Begin
     begin
       select s_nro_proceso.nextval
         into v_nro_proceso
         from dual;
     exception
       when others then
         v_msj_error := 'No se pudo obtener el número de secuencia.';
         lp_ins_log( 0, 0, null, v_msj_error, 'N' );
     end;

     begin
       select cod_rubro
         into v_cod_rubro
         from cc_cta_ficticias
        where nro_cuenta = p_nro_cuenta;
     exception
       when others then
         v_msj_error := 'No se encuentra el rubro contable.';
         lp_ins_log( 0, 0, null, v_msj_error , 'N');
     end;

     v_nro_cuenta := fue_obt_val_max_refcodes('ICB_NRO_CTA_BATCH',p_nro_cuenta);

     if v_msj_error is null then
       begin
         insert into ge_inf_cob_batch (nro_proceso,fec_proceso, fec_archivo,nro_cuenta,cod_rub_contable)
          values (v_nro_proceso, v_fec_actual, p_fecha, v_nro_cuenta, v_cod_rubro);
       exception
         when others then
           v_msj_error :=  substr('No se pudo realizar la inserción de la cabecera - GE_INF_COB_BATCH. '||sqlerrm, 1,1000);
           lp_ins_log( 0, 0, null, v_msj_error,'N' );
       end;
    end if;

     if v_msj_error is null then
       for c in c_mov_batch loop
         begin
           insert into ge_inf_cob_batch_det(nro_proceso, nom_archivo, tip_registro, cod_emision, cod_sucursal,
                                            cod_caja, dig_ver_cod_barra, monto, mto_facturador, fec_cobro,
                                            nro_documento, cod_cargo, nro_factura, cod_entidad, hor_referencia, dat_adicional,
                                            liberado, nro_transaccion, nro_cta_deb_batch, incluir, cod_tra_padre)
                                    values (v_nro_proceso, c.nom_archivo,c.tip_registro,c.cod_emision,c.cod_sucursal,
                                            c.cod_caja, c.dig_ver_cod_barra,c.monto, c.mto_facturador, c.fec_cobro,
                                            c.nro_documento, c.cod_cargo, c.nro_factura, c.cod_entidad, c.hor_referencia, c.dat_adicional,
                                            'N', c.nro_transaccion, c.nro_cta_deb_batch, c.incluir, c.cod_tra_padre);
         exception
           when others then
             v_msj_error :=  substr('No se pudo realizar la inserción de la cabecera - GE_INF_COB_BATCH_DET. '||sqlerrm, 1,1000);
             lp_ins_log( 0, 0, null, v_msj_error, 'N' );
         end;
       end loop;
    end if;

  Exception
    WHEN NO_DATA_FOUND THEN
      v_msj_error := substr('No se pudo insertar en las tablas definitivas. '||sqlerrm,1,1000);
      lp_ins_log( 0, 0, null, v_msj_error, 'N' );
  end;

  procedure lp_ins_inf_cob_batch_mov(p_tip_movimiento varchar2, p_nro_cta_credito ge_cuentas.nro_cuenta%type) is
    v_fec_anterior date :=  pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha, 1);
    v_nro_proceso ge_inf_cob_batch.nro_proceso%type;
    CURSOR c_mov_batch IS
    select archivo, fec_valor, sum(monto) monto, sum(mto_facturador) mto_Facturador, nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional, nro_cta_deb_batch
    from (SELECT 'MOVIMIENTO' archivo, fec_valor, nvl(monto, 0) + nvl(mto_comision,0) monto, monto mto_facturador,
           nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
      FROM ge_mov_dat_adicionales i
     WHERE nro_cuenta = p_nro_cuenta
       and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
           or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
       and cod_tra_padre in (380,488)
       and nvl(liberado, 'N') = 'N'
       and not exists (select 1
                           from ge_mov_dat_adicionales l
                          where l.nro_transaccion = i.nro_transaccion
                            and l.nro_cuenta = i.nro_cuenta
                            and  i.cod_extorno = '00'
                            and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
                                or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
                            and l.cod_extorno = 99)
    union all
    SELECT 'MOVIMIENTO' archivo, fec_valor, nvl(monto, 0) + nvl(mto_comision,0) monto, monto mto_facturador,
           nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
      FROM ge_mov_dat_adicionales_err i
     WHERE nro_cuenta = p_nro_cuenta
       and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
           or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
       and cod_tra_padre in (380,488)
       and nvl(liberado, 'N') = 'N'
       and not exists (select 1
                           from ge_mov_dat_adicionales l
                          where l.nro_transaccion = i.nro_transaccion
                            and l.nro_cuenta = i.nro_cuenta
                            and  i.cod_extorno = '00'
                            and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
                               or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
                            and l.cod_extorno = 99)
    union all
    SELECT 'MOVIMIENTO' archivo, fec_valor,nvl(monto, 0) + nvl(mto_comision,0) monto, monto mto_facturador,
           nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
      FROM ge_mov_dat_adicionales i
     WHERE nro_cuenta = p_nro_cuenta
       and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
           or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
	     and cod_tra_padre = 227
	     and nvl(liberado, 'N') = 'N'
       and not exists (select 1
                           from ge_mov_dat_adicionales l
                          where l.nro_transaccion = i.nro_transaccion
                            and l.nro_cuenta = i.nro_cuenta
                            and  i.cod_extorno = '00'
                            and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
                                 or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
                            and l.cod_extorno = 99)
     union all
    SELECT 'MOVIMIENTO' archivo, fec_valor, nvl(monto, 0) + nvl(mto_comision,0) monto, monto mto_facturador,
           nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
      FROM ge_mov_dat_adicionales_err i
     WHERE nro_cuenta = p_nro_cuenta
       and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
           or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
	     and cod_tra_padre = 227
	     and nvl(liberado, 'N') = 'N'
       and not exists (select 1
                           from ge_mov_dat_adicionales l
                          where l.nro_transaccion = i.nro_transaccion
                            and l.nro_cuenta = i.nro_cuenta
                            and  i.cod_extorno = '00'
                            and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
                               or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))                            
                            and l.cod_extorno = 99)) sc
   group by archivo, fec_valor, nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional, nro_cta_deb_batch
   having sum(monto) <> 0;

    CURSOR c_mov_batch_his IS
    SELECT 'MOVIMIENTO' archivo, trunc(fec_valor) fec_valor, sum(nvl(monto, 0) + nvl(mto_comision,0)) monto, 
           sum(monto) mto_facturador,
           nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
      FROM gv_mov_dat_adicionales i
     WHERE nro_cuenta = p_nro_cuenta
       and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
           or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
       and cod_tra_padre in (380,488)
       and nvl(liberado, 'N') = 'N'
       and not exists (select 1
                           from gv_mov_dat_adicionales l
                          where l.nro_transaccion = i.nro_transaccion
                             and l.NRO_CUENTA = i.nro_cuenta
                             and  i.cod_extorno = '00'
                             and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
                                 or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
	                            and l.cod_extorno = 99)
       group by trunc(fec_valor),nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
       having sum(monto) <> 0
    union all
    SELECT 'MOVIMIENTO' archivo, trunc(fec_valor), sum(nvl(monto, 0) + nvl(mto_comision,0)) monto, sum(monto) mto_facturador,
           nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
      FROM gv_mov_dat_adicionales i
     WHERE nro_cuenta = p_nro_cuenta
       and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
           or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
	     and cod_tra_padre = 227
	     and nvl(liberado, 'N') = 'N'
       and not exists (select 1
                           from gv_mov_dat_adicionales l
                          where l.nro_transaccion = i.nro_transaccion
                            and l.NRO_CUENTA = i.NRO_CUENTA
                            and  i.cod_extorno = '00'
                            and (((fec_valor = p_fecha and hor_referencia < v_hor_corte) or (fec_valor = v_fec_anterior and hor_referencia >= v_hor_corte))
                                or (fec_valor between v_fec_anterior and p_fecha and fec_valor not in (v_fec_anterior, p_fecha)))
                            and l.cod_extorno = 99)
       group by trunc(fec_valor),nro_documento, nro_transaccion, cod_tra_padre, hor_referencia, dat_adicional,
           nro_cta_deb_batch
       having sum(monto) <> 0;
    v_cod_rubro cb_rubros.cod_rubro%type;
  Begin
     begin
       select s_nro_proceso.nextval
         into v_nro_proceso
         from dual;
     exception
       when others then
         v_msj_error := 'No se pudo obtener el número de secuencia.';
         lp_ins_log( 0, 0, null, v_msj_error, 'N' );
     end;

     begin
       select cod_rubro
         into v_cod_rubro
         from cc_cta_ficticias
        where nro_cuenta = p_nro_cuenta;
     exception
       when others then
         v_msj_error := 'No se encuentra el rubro contable.';
         lp_ins_log( 0, 0, null, v_msj_error , 'N');
     end;
     if v_msj_error is null then
       begin
         insert into ge_inf_cob_batch (nro_proceso,fec_proceso, fec_archivo,nro_cuenta,cod_rub_contable)
          values (v_nro_proceso, v_fec_actual, p_fecha, p_nro_cta_credito, v_cod_rubro);
       exception
         when others then
           v_msj_error :=  substr('No se pudo realizar la inserción de la cabecera - GE_INF_COB_BATCH. '||sqlerrm, 1,1000);
           lp_ins_log( 0, 0, null, v_msj_error,'N' );
       end;
    end if;

     if v_msj_error is null then
       if p_tip_movimiento = 'A' then
       for c in c_mov_batch loop
         begin
           insert into ge_inf_cob_batch_det(nro_proceso, nom_archivo,
                                            monto, mto_facturador, fec_cobro,
                                            nro_documento, hor_referencia, dat_adicional,
                                            liberado, nro_transaccion, nro_cta_deb_batch, cod_tra_padre)
                                    values (v_nro_proceso, c.archivo,
                                            c.monto, c.mto_facturador, c.fec_valor,
                                            c.nro_documento, c.hor_referencia, c.dat_adicional,
                                            'N', c.nro_transaccion, c.nro_cta_deb_batch, c.cod_tra_padre);
         exception
           when others then
             v_msj_error :=  substr('No se pudo realizar la inserción de la detalle - GE_INF_COB_BATCH_DET. '||sqlerrm, 1,1000);
             lp_ins_log( 0, 0, null, v_msj_error, 'N' );
         end;
       end loop;
       else
         for c in c_mov_batch_his loop
           begin
             insert into ge_inf_cob_batch_det(nro_proceso, nom_archivo,
                                              monto, mto_facturador, fec_cobro,
                                              nro_documento, hor_referencia, dat_adicional,
                                              liberado, nro_transaccion, nro_cta_deb_batch, cod_tra_padre)
                                      values (v_nro_proceso, c.archivo,
                                              c.monto, c.mto_facturador, c.fec_valor,
                                              c.nro_documento, c.hor_referencia, c.dat_adicional,
                                              'N', c.nro_transaccion, c.nro_cta_deb_batch, c.cod_tra_padre);
           exception
             when others then
               v_msj_error :=  substr('No se pudo realizar la inserción de la cabecera - GE_INF_COB_BATCH_DET. '||sqlerrm, 1,1000);
               lp_ins_log( 0, 0, null, v_msj_error, 'N' );
           end;
         end loop;
       end if;
    end if;
  Exception
    WHEN NO_DATA_FOUND THEN
      v_msj_error := substr('No se pudo insertar en las tablas definitivas. '||sqlerrm,1,1000);
      lp_ins_log( 0, 0, null, v_msj_error, 'N' );
  end;

  -- PROCESO DE ACREDITACIÓN DE LAS OPERACIONES 48 HS, CUENTA TRANSITORIA, COMISION DE BANCARD.
  PROCEDURE lp_deb_pendientes(p_nro_cta_credito ge_cuentas.nro_cuenta%type) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    CURSOR c_mov_pedientes IS
    select c.nro_proceso, d.nro_transaccion, d.mto_facturador, d.monto, nvl(d.monto,0) - nvl(d.mto_facturador, 0) mto_comision,
           substr('          '||d.nro_transaccion, -7, 7) nro_documento, d.nro_cta_deb_batch, c.cod_rub_contable,
           d.hor_referencia,   case when (d.nom_archivo like ('%IC%'))then  
             'S'
            when d.nom_archivo like ('%II%') then
             'S'
           else
             'N'
           end v_nom_archivo  
      from ge_inf_cob_batch c, ge_inf_cob_batch_det d
     where c.fec_archivo =  v_fec_ant_48
       and c.nro_cuenta = p_nro_cta_credito
       and c.nro_proceso = d.nro_proceso
       and d.cod_tra_padre not in (380, 488) -- movimiento generado en línea
       and nvl(d.ind_mov_comision, 'N') = 'N'
       and not exists (select 1
                           from ge_mov_dat_adicionales l
                          where l.nro_transaccion = d.nro_transaccion
                            and l.cod_extorno = 99);

     v_cod_tra_padre  number(3) := 227;
     v_cod_mon_debito varchar2(03);
     v_cod_tra_debito NUMBER(03) := 503;
     v_cod_moneda ba_monedas.cod_moneda%type;
     v_cod_mon_credito varchar2(3);
     v_cod_mon_comision varchar2(3);
     v_cod_mod_credito number(3);
     v_cod_mad_credito number(3);
     v_cod_tra_credito NUMBER(03) := 602;
     v_cod_mod_debito number(3);
     v_cod_mad_debito number(3);
     v_cod_rub_debito cb_rubros.cod_rubro%type;
     v_fec_imp_acr_bat date := to_date(fug_obt_pardinamico('ICB_FEC_IMP_ACR_BAT'), 'dd/mm/Yyyy');
     --
     v_es_ficticia VARCHAR2(1);
     --
     v_lugar varchar2(200);
      --
     v_cod_modulo number(4);
     v_cod_modalidad number(4);
     v_cod_mod_com number(4);
     v_cod_mad_com number(4);
     v_nvo_estado varchar2(1);
     v_nvo_est_com varchar2(1);
     v_sal_disponible number(18,2);
     v_sal_dis_com number(18,2);
     v_procesa varchar2(1);
     v_pro_com varchar2(1);
     v_cod_ofi_debito number(5);
     v_cod_ofi_comision  number(5);
     --v_nro_cta_credito ge_movimientos.nro_cuenta%type;
     v_cta_com_bancard ge_cuentas.nro_cuenta%type;
     v_ind_obt_comision varchar2(1) := 'N';
     v_ind_ficticia varchar2(1);
     v_cod_rubro cb_rubros.cod_rubro%type;
     v_ins_mov_inf_cob varchar2(1) := 'N';
     v_cod_error  NUMBER(3) default 0;
     v_monto  ge_inf_cob_batch_det.monto%type; 
   BEGIN
     v_nro_secuencia := 0;
     v_hora := to_char(sysdate,'HH24:MI:SS');
     v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');

     --Movimientos por el rubro contable provisorio, comisión de bancard
     FOR CC IN c_mov_pedientes LOOP
        v_msj_error      := NULL;
        v_es_ficticia := 'N';

        v_lugar := 'Procesando.... Movimientos 48 hs posterior. ';

        begin
          select cod_moneda, cod_oficina
            into v_cod_mon_debito, v_cod_ofi_debito
            from ge_cuentas
           where nro_cuenta = cc.nro_cta_deb_batch;
        exception
          when others then
             v_cod_moneda := 'GS';
        end;
        
      ---Validacion para ESSAP MONTO PARA FACTURADORES SIN COMISION DYDMR-12712---
       if cc.v_nom_archivo = 'S' then
         v_monto := cc.mto_facturador;
       else
         v_monto := cc.monto;
       end if;

        pag_cta.PR_VER_OPERACION(cc.nro_cta_deb_batch,v_cod_tra_padre,4,41,'D',
                                 v_cod_mon_debito,v_monto, v_cod_oficina,            
                                 v_cod_modulo, v_cod_modalidad, v_nvo_estado,
                                 v_sal_disponible,v_procesa,v_cod_tra_debito);

        if v_procesa = 'N' then
           v_ins_mov_inf_cob := 'S';
           v_procesa := 'S'; -- se procesa porque irá el débito a una cuenta transitoria, y se tratará de debitar durante el cierre
           lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_mon_debito,  substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000), 'S' );
        else
           v_ins_mov_inf_cob := 'N';
        end if;

        if v_fec_imp_acr_bat + 10 >= v_Fec_actual then
           declare
             v_ind_mov_cierre varchar2(1);
           begin
             begin
               select distinct('S')
                 into v_ind_mov_cierre
                 from ge_mov_inf_cobranzas t
                where nro_documento = cc.nro_transaccion
                  and nro_cta_credito = p_nro_cuenta
                  and t.fecha between v_fec_imp_acr_bat and v_fec_actual + 10;
              exception
                when others then
                   v_ind_mov_cierre := 'N';
              end;

              if nvl(v_ind_mov_cierre, 'N') = 'S' then
                v_procesa := 'N';
                v_msj_error := 'Procesado durante el cierre.';
               lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_mon_debito,  v_msj_error, 'S' );
              end if;
            end;
        end if;

        IF v_msj_error IS NULL THEN   /* verifico cuenta credito */
           v_lugar := 'Obtiendo cuenta ficticia '||p_nro_cuenta;
           lp_obt_cta_ficticia (p_nro_cuenta, v_cod_mod_credito, v_cod_mad_credito,
                                v_cod_rubro, v_ind_ficticia );
           v_mto_credito := cc.monto;

           if v_ind_ficticia = 'S' then
              v_cod_mon_credito := v_cod_mon_debito;
           else
             v_msj_error := 'No se encuentra la cuenta ficticia.';
             lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_mon_debito,  v_msj_error, 'S'  );

             v_procesa := 'N';
           end if;

           --Ver si la cuenta está configurada para comisión
           begin
             select distinct 'S'
               into v_ind_obt_comision
               from ba_cod_referencias
              where dominio = 'NRO_CTA_COM_BANCARD'
                and val_minimo = p_nro_cuenta;
           exception
             when others then
              v_ind_obt_comision := 'N';
           end;

           if nvl(cc.mto_comision,0) <> 0 and nvl(v_ind_obt_comision, 'N') = 'S' then
               v_cta_com_bancard := fue_obt_val_max_refcodes('NRO_CTA_COM_BANCARD', p_nro_cuenta );
               v_mto_credito := v_mto_credito - nvl(cc.mto_comision,0);
            else
               v_ind_obt_comision := 'N';
            end if;

            --Se procesa la comisión a Bancard.

             if nvl(v_ind_obt_comision, 'N') = 'S' and v_procesa = 'S' then
                begin
                  select cod_moneda, cod_oficina
                    into v_cod_mon_comision, v_cod_ofi_comision
                    from ge_cuentas
                   where nro_cuenta = v_cta_com_bancard;
                exception
                  when others then
                    v_cod_mon_comision := 'GS';
                    v_cod_ofi_comision := v_cod_oficina;
                end;
                pag_cta.PR_VER_OPERACION(v_cta_com_bancard,v_cod_tra_padre,4,41,'C',
                                         v_cod_mon_comision,cc.mto_comision,v_cod_oficina,
                                         v_cod_mod_com, v_cod_mad_com, v_nvo_est_com,
                                         v_sal_dis_com,v_pro_com,v_cod_tra_credito);

                if v_pro_com = 'N' then
                   v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                   lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_mon_debito,  v_msj_error, 'S'  );
                   v_procesa := 'N';
                end if;
             end if;
          END IF;

        IF v_msj_error IS NULL and nvl(cc.monto,0) <> 0 THEN
          /* se puede realizar transferencia */
          -- calculo el numero de documento -----------------------------
          if v_nro_secuencia > 990 then
             v_nro_secuencia := -999;
          elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
             v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
             v_nro_secuencia := 0;
          end if;

          -- debito a la cuenta de debito
          if nvl(v_ins_mov_inf_cob, 'N') = 'S' then
            lp_obt_cta_ficticia (v_cta_deb_icb, v_cod_mod_debito, v_cod_mad_debito,
                                 v_cod_rub_debito, v_ind_ficticia );
            v_nro_secuencia := v_nro_secuencia+1;
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_modulo    := v_cod_mod_debito;
            r_gmovi.cod_modalidad := v_cod_mad_debito;
            r_gmovi.cod_oficina   := v_cod_oficina;
            r_gmovi.tip_mov_rubro   := 'D';
            r_gmovi.cod_rubro       := v_cod_rub_debito;
            r_gmovi.cod_moneda    := v_cod_mon_debito;
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.fec_valor     := v_fec_actual;
            r_gmovi.cod_tra_padre := v_cod_tra_padre;
            r_gmovi.nro_documento := cc.nro_documento;
            r_gmovi.nro_documento3 := cc.nro_transaccion;
            r_gmovi.monto         := v_monto; 
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := v_cod_oficina;
            r_gmovi.concepto :=  'Infonet Cobranza';
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := 4;
            r_gmovi.cod_mad_padre := 41;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

            begin
              insert into ge_mov_inf_cobranzas(fecha,hora,nro_documento,cod_moneda,monto,nro_cta_debito,
                                               nro_cta_credito,referencia,reversado,liberado,observacion,
                                               cod_tra_padre, mto_comision, hor_referencia)
                                       values (v_fec_ant_48, v_hora, cc.nro_transaccion, v_cod_mon_debito, v_monto, 
                                               cc.nro_cta_deb_batch, v_cta_deb_icb, null, 'N', 'N', 'Proceso Acreditacion en Batch',
                                               v_cod_tra_padre, 0, cc.hor_referencia);
            exception
              when others then
                v_msj_error := substr('Error al insertar en la tabla ge_mov_inf_cobranzas. '||sqlerrm, 1, 1000);
                lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_mon_debito,  v_msj_error, 'S'  );
            end;

          else
            pag_cta.PR_SET_NRO_DOCUMENTO3(cc.nro_transaccion);
            pag_cta.pr_act_operacion(cc.nro_cta_deb_batch,
                                     v_hora,
                                     'D',
                                     v_cod_mon_debito,
                                     v_monto,         
                                     v_cod_tra_padre,
                                     v_cod_tra_debito,
                                     cc.nro_documento,
                                     null,
                                     v_cod_oficina,
                                     4,
                                     41,
                                     null,
                                     null,
                                     'Infonet Cobranza',
                                     'N',
                                     v_nro_secuencia,
                                     v_fec_actual);
             v_cod_error := pag_cta.g_cod_error;
          end if;
          if v_cod_error <> 0 then
            -- actualizacion con problemas
            v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
            lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_mon_debito,  v_msj_error, 'S'  );
          else
            v_nro_secuencia := v_nro_secuencia+1;
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_modulo    := v_cod_mod_credito;
            r_gmovi.cod_modalidad := v_cod_mad_credito;
            r_gmovi.cod_oficina   := v_cod_oficina;
            r_gmovi.tip_mov_rubro   := 'C';
            r_gmovi.cod_rubro       := cc.cod_rub_contable;
            r_gmovi.cod_moneda    := v_cod_mon_credito;
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.fec_valor     := v_fec_actual;
            r_gmovi.cod_tra_padre := v_cod_tra_padre;
            r_gmovi.nro_documento := cc.nro_documento;
            r_gmovi.nro_documento3 := cc.nro_transaccion;
            r_gmovi.monto         := cc.mto_facturador;
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := v_cod_oficina;
            r_gmovi.concepto :=  'Infonet Cobranza';
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := 4;
            r_gmovi.cod_mad_padre := 41;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

            if nvl(v_ind_obt_comision, 'N') = 'S' then
                pag_cta.PR_SET_NRO_DOCUMENTO3(cc.nro_transaccion);
                 pag_cta.pr_act_operacion(v_cta_com_bancard,
                                          v_hora,
                                          'C',
                                          v_cod_mon_comision,
                                          cc.mto_comision,
                                          v_cod_tra_padre,
                                          v_cod_tra_credito,
                                          cc.nro_documento,
                                          null,
                                          v_cod_oficina,
                                          4,
                                          41,
                                          null,
                                          null,
                                          v_con_mov_com_bancard,
                                          'N',
                                          v_nro_secuencia,
                                          v_fec_actual);
                 pag_cta.PR_SET_NRO_DOCUMENTO3(null);
              if pag_cta.g_cod_error <> 0 then
                -- actualizacion con problemas
                v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_mon_debito,  v_msj_error, 'S'  );
              end if;
             end if;
           end if;

        end if;
        begin
          update ge_inf_cob_batch_det t
             set t.ind_mov_comision = 'S'
           where t.nro_proceso = cc.nro_proceso
             and t.nro_transaccion = cc.nro_transaccion;
        exception
          when others then
            v_msj_error := substr('No se ha podido realizar el cierre. '||cc.nro_transaccion||'. '||sqlerrm, 1, 1000);
            lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'S'  );
        end;

        if v_msj_error is null then
           commit;
        else
           rollback;
        end if;
      END LOOP;

      --Movimientos de creditos, debito al rubro transitorio.
   EXCEPTION
     WHEN OTHERS THEN
       v_msj_error     := substr('Error al procesar cobranzas: ' || sqlerrm, 1, 1000);
       lp_ins_log( 0, 0, null,  v_msj_error, 'S'  );
   END;

   --PROCESO DE ACREDITACIÓN DE LAS OPERACIONES 48 HS A LA CUENTA DEL FACTURADOR, DEBITO CUENTA TRANSITORIA
   PROCEDURE lp_acr_pendiente(p_tipo varchar2, p_nro_cta_credito ge_cuentas.nro_cuenta%type) IS
    CURSOR c_mov_pendientes IS
    select c.nro_proceso, 'COBRO FACT. RED INFONET '||to_char(c.fec_archivo, 'DD/MM/YYYY')||'-EFECTIVO-CAPITAL' concepto, c.nro_cuenta, c.cod_rub_contable,
           d.nro_transaccion, d.mto_facturador,
           substr('          '||d.nro_transaccion, -7, 7) nro_documento, d.nro_cta_deb_batch
      from ge_inf_cob_batch c, ge_inf_cob_batch_det d
     where c.fec_archivo =  v_fec_ant_48
       and c.nro_cuenta = p_nro_cta_credito
       and c.nro_proceso = d.nro_proceso
       and liberado = 'N'
       and cod_emision in (1,3)
       and p_tipo = 'C'
    union all
    select c.nro_proceso, 'COBRO FACT. RED INFONET '||to_char(c.fec_archivo, 'DD/MM/YYYY')||'-EFECTIVO-INTERIOR' concepto, c.nro_cuenta, c.cod_rub_contable,
           d.nro_transaccion, d.mto_facturador,
           substr('          '||d.nro_transaccion, -7, 7) nro_documento, d.nro_cta_deb_batch
      from ge_inf_cob_batch c, ge_inf_cob_batch_det d
     where c.fec_archivo =  v_fec_ant_48
       and c.nro_cuenta = p_nro_cta_credito
       and c.nro_proceso = d.nro_proceso
       and liberado = 'N'
       and cod_emision not in (1,3)
       and p_tipo = 'I'
    union all
     select c.nro_proceso, 'COBRO FACT. RED INFONET '||to_char(c.fec_archivo, 'DD/MM/YYYY')||'-EFECTIVO' concepto, c.nro_cuenta, c.cod_rub_contable,
           d.nro_transaccion, d.mto_facturador,
           substr('          '||d.nro_transaccion, -7, 7) nro_documento, d.nro_cta_deb_batch
      from ge_inf_cob_batch c, ge_inf_cob_batch_det d
     where c.fec_archivo =  v_fec_ant_48
       and c.nro_cuenta = p_nro_cta_credito
       and c.nro_proceso = d.nro_proceso
       and liberado = 'N'
       and d.nom_archivo = 'MOVIMIENTO'
       and p_tipo = 'M'
       and d.monto > 0;

     v_cod_tra_padre  number(3) := 229;  -- CANOSTDD-2 -- 01/2017 --

     v_cod_moneda ba_monedas.cod_moneda%type;
     v_cod_mod_credito number(4);
     v_cod_mad_credito number(4);
     v_cod_mod_debito number(4);
     v_cod_mad_debito number(4);
     v_cod_tra_credito NUMBER(03) := 602;
     v_cod_tra_debito NUMBER(03) := 503;
     v_ind_ficticia VARCHAR2(1) := 'S';
     v_lugar varchar2(200);

     v_nvo_estado varchar2(1);
     v_sal_disponible number(18,2);
     v_procesa varchar2(1);
     v_cod_ofi_credito number(5);
     v_mto_credito ge_movimientos.monto%type;
     v_cod_rubro cb_rubros.cod_rubro%type;
     v_nro_cta_credito ge_movimientos.nro_cuenta%type;
     v_concepto ge_movimientos.concepto%type;
     v_fec_ant_arc48 ge_movimientos.fecha%type := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_ant_48, 1);
     v_nro_doc_credito ge_movimientos.nro_documento%type := to_number(to_char(v_fec_ant_48, 'YYYYMMDD'));
   BEGIN
     v_nro_secuencia := 0;
     v_mto_credito := 0;
     v_hora := to_char(sysdate,'HH24:MI:SS');
     v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
     --Movimientos por el rubro contable provisorio, comisión de bancard
     --CAPITAL
     FOR CC IN c_mov_pendientes LOOP
        v_msj_error      := NULL;
        v_lugar := 'Procesando.... Debito a: '||cc.cod_rub_contable||
                   ' Credito a: '||cc.nro_cuenta;

        begin
          select cod_modulo, cod_modalidad, cod_moneda, cod_oficina
            into v_cod_mod_credito, v_cod_mad_credito, v_cod_moneda, v_cod_ofi_credito
            from ge_cuentas
           where nro_cuenta = cc.nro_cuenta;
        exception
          when others then
            v_msj_error := substr('Error al buscar la cuenta. '||sqlerrm,1,1000);
            lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
        end;
        v_nro_cta_credito := cc.nro_cuenta;
        v_concepto := cc.concepto;

        v_lugar := 'Obtiendo cuenta ficticia '||p_nro_cuenta;
        lp_obt_cta_ficticia (p_nro_cuenta, v_cod_mod_debito, v_cod_mad_debito,
                             v_cod_rubro, v_ind_ficticia );

        if v_nro_secuencia > 990 then
           v_nro_secuencia := -999;
        elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
           --- debe hacer el credito a la secuencia indicada para corte
           begin
             pag_cta.PR_VER_OPERACION(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',
                                      v_cod_moneda,v_mto_credito,v_cod_oficina,
                                      v_cod_mod_credito, v_cod_mad_credito, v_nvo_estado,
                                      v_sal_disponible,v_procesa,v_cod_tra_credito);

             if v_procesa = 'N' then
                v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
             end if;
             if v_msj_error is null then
                -- se hace el credito
                v_nro_secuencia := v_nro_secuencia + 1;

                pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_doc_credito);
                pag_cta.pr_act_operacion(v_nro_cta_credito,
                                         v_hora,
                                         'C',
                                         v_cod_moneda,
                                         v_mto_credito,
                                         v_cod_tra_padre,
                                         v_cod_tra_credito,
                                         v_nro_doc_credito,
                                         null,
                                         v_cod_oficina,
                                         9,
                                         91,
                                         null,
                                         null,
                                         v_concepto,
                                         'N',
                                         v_nro_secuencia,
                                         v_fec_actual);
                if pag_cta.g_cod_error <> 0 then
                  -- actualizacion con problemas
                  v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                  lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
                end if;
             end if;
           exception
             when others then
                v_msj_error := substr('No se ha podido realizar el movimiento de crédito. '||sqlerrm, 1, 1000);
                lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
           end;
           v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           v_nro_secuencia := 0;
           v_mto_credito := 0;
        end if;

        v_nro_secuencia := v_nro_secuencia+1;
        r_gmovi.cod_usuario := user;
        r_gmovi.hora := v_hora;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        r_gmovi.cod_modulo := v_cod_mod_debito;
        r_gmovi.cod_modalidad := v_cod_mad_debito;
        r_gmovi.cod_oficina := v_cod_oficina;
        r_gmovi.tip_mov_rubro := 'D';
        r_gmovi.cod_rubro := cc.cod_rub_contable;
        r_gmovi.cod_moneda := v_cod_moneda;
        r_gmovi.fecha := v_fec_actual;
        r_gmovi.fec_valor := v_fec_actual;
        r_gmovi.cod_tra_padre := v_cod_tra_padre;
        r_gmovi.nro_documento := cc.nro_documento;
        r_gmovi.nro_documento3 := cc.nro_transaccion;
        r_gmovi.monto := cc.mto_facturador;
        r_gmovi.estado := 'N';
        r_gmovi.cod_ofi_origen := v_cod_oficina;
        r_gmovi.concepto := cc.concepto;
        r_gmovi.reversado := 'N';
        r_gmovi.emi_aviso := 'N';
        r_gmovi.protegido := 'N';
        r_gmovi.cod_mod_padre := 9;
        r_gmovi.cod_mad_padre := 91;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        v_mto_credito := nvl(v_mto_credito, 0) + cc.mto_facturador;
        begin
          update ge_inf_cob_batch_det t
             set t.liberado = 'S',
                 t.fec_acreditacion = p_fecha, -- los informes deben salir en base a la fecha del archivo.
                 t.hor_credito = v_hora
           where t.nro_proceso = cc.nro_proceso
             and t.nro_transaccion = cc.nro_transaccion;
        exception
          when others then
            v_msj_error := substr('No se ha podido marcar el movimiento '||cc.nro_transaccion||' como liberado.'||sqlerrm, 1, 1000);
            lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
        end;
        if p_tipo = 'M' then
          begin
            update ge_mov_dat_adicionales t
               set t.liberado = 'S',
                   t.fec_acreditacion = p_fecha
             where trunc(fec_valor) BETWEEN v_fec_ant_arc48  AND v_fec_ant_48
               and t.nro_transaccion = cc.nro_transaccion
               and t.nro_cuenta = p_nro_cuenta;
            IF SQL%NOTFOUND THEN
              update ge_mov_dat_adicionales_his t
                 set t.liberado = 'S',
                     t.fec_acreditacion = p_fecha
               where trunc(fec_valor) BETWEEN v_fec_ant_arc48 AND v_fec_ant_48
                 and t.nro_transaccion = cc.nro_transaccion
                 and t.nro_cuenta = p_nro_cuenta;
            end if;
          exception
            when others then
              v_msj_error := substr('No se ha podido marcar el movimiento '||cc.nro_transaccion||' como liberado.'||sqlerrm, 1, 1000);
              lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
          end;
        else
          begin
            update ge_mov_dat_adicionales t
               set t.liberado = 'S',
                   t.fec_acreditacion = p_fecha
             where T.FECHA BETWEEN v_fec_ant_arc48  AND v_fec_ant_48
               and t.nro_transaccion = cc.nro_transaccion
               and t.nro_cuenta = p_nro_cuenta;
            IF SQL%NOTFOUND THEN
              update ge_mov_dat_adicionales_his t
                 set t.liberado = 'S',
                     t.fec_acreditacion = p_fecha
               where T.FECHA BETWEEN v_fec_ant_arc48 AND v_fec_ant_48
                 and t.nro_transaccion = cc.nro_transaccion
                 and t.nro_cuenta = p_nro_cuenta;
            end if;
          exception
            when others then
              v_msj_error := substr('No se ha podido marcar el movimiento '||cc.nro_transaccion||' como liberado.'||sqlerrm, 1, 1000);
              lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
          end;
        end if;
      END LOOP;
      if v_mto_credito > 0 then
         begin
           pag_cta.PR_VER_OPERACION(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',
                                    v_cod_moneda,v_mto_credito,v_cod_oficina,
                                    v_cod_mod_credito, v_cod_mad_credito, v_nvo_estado,
                                    v_sal_disponible,v_procesa,v_cod_tra_credito);

           if v_procesa = 'N' then
              v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
              lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
           end if;
           if v_msj_error is null then
              -- se hace el credito
              v_nro_secuencia := v_nro_secuencia + 1;

              pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_doc_credito);
              pag_cta.pr_act_operacion(v_nro_cta_credito,
                                       v_hora,
                                       'C',
                                       v_cod_moneda,
                                       v_mto_credito,
                                       v_cod_tra_padre,
                                       v_cod_tra_credito,
                                       v_nro_doc_credito,
                                       null,
                                       v_cod_oficina,
                                       9,
                                       91,
                                       null,
                                       null,
                                       v_concepto,
                                       'N',
                                       v_nro_secuencia,
                                       v_fec_actual);
              if pag_cta.g_cod_error <> 0 then
                -- actualizacion con problemas
                v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
              end if;
           end if;
         exception
           when others then
              v_msj_error := substr('No se ha podido realizar el movimiento de crédito. '||sqlerrm, 1, 1000);
              lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
         end;
      end if;

   EXCEPTION
     WHEN OTHERS THEN
       v_msj_error := substr('Error al procesar cobranzas: ' ||sqlerrm, 1, 1000);
       lp_ins_log( 0, 0, null, v_msj_error, 'N' );
   END;

   --PROCESO DE ACREDITACIÓN DE LAS OPERACIONES EN FECHA DEL ARCHIVO, CREDITO A LA CUENTA DEL FACTURADOR, DEBITO CUENTA TRANSITORIA
   PROCEDURE lp_acr_batch(p_tipo varchar2, p_nro_cta_credito ge_cuentas.nro_cuenta%type) IS
    CURSOR c_mov_pendientes IS
    select c.nro_proceso, 'COBRO FACT. RED INFONET '||to_char(c.fec_archivo, 'DD/MM/YYYY')||'-TARJ.DEBITO-CAPITAL' concepto, c.nro_cuenta, c.cod_rub_contable,
           d.nro_transaccion, d.mto_facturador,
           substr('          '||d.nro_transaccion, -7, 7) nro_documento, d.nro_cta_deb_batch
      from ge_inf_cob_batch c, ge_inf_cob_batch_det d
     where c.fec_archivo =  p_fecha
       and c.nro_cuenta = p_nro_cta_credito
       and c.nro_proceso = d.nro_proceso
       and liberado = 'N'
       and incluir = 'S'
       and cod_emision in (1,3)
       and p_tipo = 'C'
    union all
    select c.nro_proceso, 'COBRO FACT. RED INFONET '||to_char(c.fec_archivo, 'DD/MM/YYYY')||'-TARJ.DEBITO-INTERIOR' concepto, c.nro_cuenta, c.cod_rub_contable,
           d.nro_transaccion, d.mto_facturador,
           substr('          '||d.nro_transaccion, -7, 7) nro_documento, d.nro_cta_deb_batch
      from ge_inf_cob_batch c, ge_inf_cob_batch_det d
    where c.fec_archivo =  p_fecha
       and c.nro_cuenta = p_nro_cta_credito
       and c.nro_proceso = d.nro_proceso
       and liberado = 'N'
       and incluir = 'S'
       and cod_emision not in (1,3)
       and p_tipo = 'I'
    union all
    select c.nro_proceso, 'COBRO FACT. RED INFONET '||to_char(c.fec_archivo, 'DD/MM/YYYY')||'-TARJ.DEBITO' concepto, c.nro_cuenta, c.cod_rub_contable,
           d.nro_transaccion, d.mto_facturador,
           substr('          '||d.nro_transaccion, -7, 7) nro_documento, d.nro_cta_deb_batch
      from ge_inf_cob_batch c, ge_inf_cob_batch_det d
    where c.fec_archivo =  p_fecha
       and c.nro_cuenta = p_nro_cta_credito
       and c.nro_proceso = d.nro_proceso
       and d.cod_tra_padre in (488, 380)
       and liberado = 'N'
       and p_tipo = 'M';

     v_cod_tra_padre  number(3) := 379;  -- CANOSTDD-2 -- 01/2017 --

     v_cod_moneda ba_monedas.cod_moneda%type;
     v_cod_mod_credito number(4);
     v_cod_mad_credito number(4);
     v_cod_mod_debito number(4);
     v_cod_mad_debito number(4);
     v_cod_tra_credito NUMBER(03) := 602;
     v_cod_tra_debito NUMBER(03) := 503;
     v_ind_ficticia VARCHAR2(1) := 'S';
     v_lugar varchar2(200);

     v_nvo_estado varchar2(1);
     v_sal_disponible number(18,2);
     v_procesa varchar2(1);
     v_cod_ofi_credito number(5);
     v_mto_credito ge_movimientos.monto%type;
     v_cod_rubro cb_rubros.cod_rubro%type;
     v_nro_cta_credito ge_movimientos.nro_cuenta%type;
     v_concepto ge_movimientos.concepto%type;
     v_fec_ant_archivo ge_movimientos.fecha%type := pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha, 1);
     v_nro_doc_credito ge_movimientos.nro_documento%type := to_number(to_char(p_fecha, 'YYYYMMDD'));
   BEGIN
     v_nro_secuencia := 0;
     v_mto_credito := 0;
     v_hora := to_char(sysdate,'HH24:MI:SS');
     v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
     --Movimientos por el rubro contable provisorio, comisión de bancard
     --CAPITAL
     FOR CC IN c_mov_pendientes LOOP
        v_msj_error      := NULL;
        v_lugar := 'Procesando.... Debito a: '||cc.cod_rub_contable||
                   ' Credito a: '||cc.nro_cuenta;

        begin
          select cod_modulo, cod_modalidad, cod_moneda, cod_oficina
            into v_cod_mod_credito, v_cod_mad_credito, v_cod_moneda, v_cod_ofi_credito
            from ge_cuentas
           where nro_cuenta = cc.nro_cuenta;
        exception
          when others then
            v_msj_error := substr('Error al buscar la cuenta. '||sqlerrm,1,1000);
            lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
        end;
        v_nro_cta_credito := cc.nro_cuenta;
        v_concepto := cc.concepto;

        v_lugar := 'Obtiendo cuenta ficticia '||p_nro_cuenta;
        lp_obt_cta_ficticia (p_nro_cuenta, v_cod_mod_debito, v_cod_mad_debito,
                             v_cod_rubro, v_ind_ficticia );

        if v_nro_secuencia > 990 then
           v_nro_secuencia := -999;
        elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
           --- debe hacer el credito a la secuencia indicada para corte
           begin
             pag_cta.PR_VER_OPERACION(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',
                                      v_cod_moneda,v_mto_credito,v_cod_oficina,
                                      v_cod_mod_credito, v_cod_mad_credito, v_nvo_estado,
                                      v_sal_disponible,v_procesa,v_cod_tra_credito);

             if v_procesa = 'N' then
                v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
             end if;
             if v_msj_error is null then
                -- se hace el credito
                v_nro_secuencia := v_nro_secuencia + 1;

                pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_doc_credito);
                pag_cta.pr_act_operacion(v_nro_cta_credito,
                                         v_hora,
                                         'C',
                                         v_cod_moneda,
                                         v_mto_credito,
                                         v_cod_tra_padre,
                                         v_cod_tra_credito,
                                         v_nro_doc_credito,
                                         null,
                                         v_cod_oficina,
                                         9,
                                         91,
                                         null,
                                         null,
                                         v_concepto,
                                         'N',
                                         v_nro_secuencia,
                                         v_fec_actual);
                if pag_cta.g_cod_error <> 0 then
                  -- actualizacion con problemas
                  v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                  lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
                end if;
             end if;
           exception
             when others then
                v_msj_error := substr('No se ha podido realizar el movimiento de crédito. '||sqlerrm, 1, 1000);
                lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
           end;
           v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           v_nro_secuencia := 0;
           v_mto_credito := 0;
        end if;

        v_nro_secuencia := v_nro_secuencia+1;
        r_gmovi.cod_usuario := user;
        r_gmovi.hora := v_hora;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        r_gmovi.cod_modulo := v_cod_mod_debito;
        r_gmovi.cod_modalidad := v_cod_mad_debito;
        r_gmovi.cod_oficina := v_cod_oficina;
        r_gmovi.tip_mov_rubro := 'D';
        r_gmovi.cod_rubro := cc.cod_rub_contable;
        r_gmovi.cod_moneda := v_cod_moneda;
        r_gmovi.fecha := v_fec_actual;
        r_gmovi.fec_valor := v_fec_actual;
        r_gmovi.cod_tra_padre := v_cod_tra_padre;
        r_gmovi.nro_documento := cc.nro_documento;
        r_gmovi.nro_documento3 := cc.nro_transaccion;
        r_gmovi.monto := cc.mto_facturador;
        r_gmovi.estado := 'N';
        r_gmovi.cod_ofi_origen := v_cod_oficina;
        r_gmovi.concepto := cc.concepto;
        r_gmovi.reversado := 'N';
        r_gmovi.emi_aviso := 'N';
        r_gmovi.protegido := 'N';
        r_gmovi.cod_mod_padre := 9;
        r_gmovi.cod_mad_padre := 91;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        v_mto_credito := nvl(v_mto_credito, 0) + cc.mto_facturador;

        begin
          update ge_inf_cob_batch_det t
             set t.liberado = 'S',
                 t.fec_acreditacion = p_fecha, -- los informes deben salir en base a la fecha del archivo.
                 t.hor_credito = v_hora
           where t.nro_proceso = cc.nro_proceso
             and t.nro_transaccion = cc.nro_transaccion;
        exception
          when others then
            v_msj_error := substr('No se ha podido marcar el movimiento '||cc.nro_transaccion||' como liberado.'||sqlerrm, 1, 1000);
            lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
        end;
        begin
          IF p_tipo = 'M' then
            update ge_mov_dat_adicionales t
               set t.liberado = 'S',
                   t.fec_acreditacion = p_fecha
             where trunc(fec_valor) BETWEEN v_fec_ant_archivo  AND p_fecha
               and t.nro_transaccion = cc.nro_transaccion
               and t.nro_cuenta = p_nro_cuenta;
            IF SQL%NOTFOUND THEN
            update ge_mov_dat_adicionales_his t
               set t.liberado = 'S',
                   t.fec_acreditacion = p_fecha
             where trunc(fec_valor) BETWEEN v_fec_ant_archivo AND p_fecha
               and t.nro_transaccion = cc.nro_transaccion
               and t.nro_cuenta = p_nro_cuenta;
          end if;
          ELSE
            update ge_mov_dat_adicionales t
               set t.liberado = 'S',
                   t.fec_acreditacion = p_fecha
             where T.FECHA BETWEEN v_fec_ant_archivo  AND p_fecha
             and t.nro_transaccion = cc.nro_transaccion
             and t.nro_cuenta = p_nro_cuenta;
             IF SQL%NOTFOUND THEN
            update ge_mov_dat_adicionales_his t
               set t.liberado = 'S',
                   t.fec_acreditacion = p_fecha
             where T.FECHA BETWEEN v_fec_ant_archivo AND p_fecha
               and t.nro_transaccion = cc.nro_transaccion
               and t.nro_cuenta = p_nro_cuenta;
          end if;
          END IF;

        exception
          when others then
            v_msj_error := substr('No se ha podido marcar el movimiento '||cc.nro_transaccion||' como liberado.'||sqlerrm, 1, 1000);
            lp_ins_log( cc.nro_transaccion, cc.mto_facturador, v_cod_moneda,  v_msj_error, 'N' );
        end;

      END LOOP;
      if v_mto_credito > 0 then
         begin
           pag_cta.PR_VER_OPERACION(v_nro_cta_credito,v_cod_tra_padre,9,91,'C',
                                    v_cod_moneda,v_mto_credito,v_cod_oficina,
                                    v_cod_mod_credito, v_cod_mad_credito, v_nvo_estado,
                                    v_sal_disponible,v_procesa,v_cod_tra_credito);

           if v_procesa = 'N' then
              v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
              lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
           end if;
           if v_msj_error is null then
              -- se hace el credito
              v_nro_secuencia := v_nro_secuencia + 1;

              pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_doc_credito);
              pag_cta.pr_act_operacion(v_nro_cta_credito,
                                       v_hora,
                                       'C',
                                       v_cod_moneda,
                                       v_mto_credito,
                                       v_cod_tra_padre,
                                       v_cod_tra_credito,
                                       v_nro_doc_credito,
                                       null,
                                       v_cod_oficina,
                                       9,
                                       91,
                                       null,
                                       null,
                                       v_concepto,
                                       'N',
                                       v_nro_secuencia,
                                       v_fec_actual);
              if pag_cta.g_cod_error <> 0 then
                -- actualizacion con problemas
                v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );
              end if;
           end if;
         exception
           when others then
              v_msj_error := substr('No se ha podido realizar el movimiento de crédito. '||sqlerrm, 1, 1000);
              lp_ins_log( 0, v_mto_credito, v_cod_moneda,  v_msj_error, 'N' );

         end;
      end if;

   EXCEPTION
     WHEN OTHERS THEN
       v_msj_error := substr('Error al procesar cobranzas: ' ||sqlerrm, 1, 1000);
       lp_ins_log( 0, 0, null, v_msj_error, 'N' );
   END;
begin

    v_fec_ant_48 := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_anterior, 1);

    begin
      v_hor_corte := fue_obt_val_max_refcodes('COR_HOR_CTA_BATCH', p_nro_cuenta);
    exception
    	when others then
      	v_hor_corte := fue_obt_val_max_refcodes('COR_HOR_CTA_BATCH', 'GENERICO');
    end;

    v_nro_cta_credito := fue_obt_val_max_refcodes('ICB_NRO_CTA_BATCH',p_nro_cuenta);
    --Movimiento de acreditaciones 48 hs posterior
    if nvl(p_eli_his, 'N') = 'N' then
      lp_deb_pendientes(v_nro_cta_credito);
      --Inserción en tablas Definitivas en base al archivo de importación
      if p_tipo = 'I' then
        lp_ins_inf_cob_batch;
        --Acreditación en batch
        if v_msj_error is null then
           lp_acr_pendiente('C', v_nro_cta_credito); -- Capital
        end if;
        if v_msj_error is null then
           lp_acr_pendiente('I', v_nro_cta_credito); -- Interior
        end if;
        --Acreditacion en fecha del archivo
        if v_msj_error is null then
           lp_acr_batch('C', v_nro_cta_credito); -- Capital
        end if;
        if v_msj_error is null then
           lp_acr_batch('I', v_nro_cta_credito); -- Interior
        end if;
      else
        --en base al movimiento
        IF v_fec_actual = p_fecha then
           lp_ins_inf_cob_batch_mov('A', v_nro_cta_credito);
        ELSE
           lp_ins_inf_cob_batch_mov('H', v_nro_cta_credito);
        END IF;          
        if v_msj_error is null then
           lp_acr_pendiente('M', v_nro_cta_credito);
        end if;
        if v_msj_error is null then
           lp_acr_batch('M', v_nro_cta_credito);
        end if;
      end if;
    else
      --Elimina los movimientos de la tabla de datos adicionales de movimientos e inserta en el histórico
      lp_eli_mov_adicionales;
    end if;
end;
/

