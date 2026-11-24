CREATE OR REPLACE PROCEDURE IT.prt_ins_not_push(p_id_novedad          IN it.ta_not_mov_push.id_novedad%TYPE,
                                                p_tip_accion          IN it.ta_not_mov_push.tip_accion%TYPE,
                                                p_id_transaccion      IN it.ta_not_mov_push.id_transaccion%TYPE,
                                                p_fec_hor_transaccion IN it.ta_not_mov_push.fec_hor_transaccion%TYPE,
                                                p_reason              IN it.ta_not_mov_push.reason%TYPE,
                                                p_marca               IN it.ta_not_mov_push.marca%TYPE,
                                                p_entidad             IN it.ta_not_mov_push.entidad%TYPE,
                                                p_nro_cuenta          IN it.ta_not_mov_push.nro_cuenta%TYPE,
                                                p_cod_producto        IN it.ta_not_mov_push.cod_producto%TYPE,
                                                p_afinidad            IN ta_not_mov_push.afinidad%TYPE,
                                                p_adicional           IN ta_not_mov_push.adicional%TYPE,
                                                p_nro_tarjeta         IN ta_not_mov_push.nro_tarjeta%TYPE,
                                                p_provincia           IN ta_not_mov_push.provincia%TYPE,
                                                p_cod_provincia       IN ta_not_mov_push.cod_provincia%TYPE,
                                                p_via_origen          IN ta_not_mov_push.via_origen%TYPE,
                                                p_red_origen          IN ta_not_mov_push.red_origen%type,
                                                p_pos_origen          IN ta_not_mov_push.pos_origen%type,
                                                p_ing_origen          IN ta_not_mov_push.ing_origen%type,
                                                p_deb_automatico      IN ta_not_mov_push.deb_automatico%TYPE,
                                                p_ori_internacional   IN ta_not_mov_push.ori_internacional%TYPE,
                                                p_cod_concepto        IN ta_not_mov_push.cod_concepto%TYPE,
                                                p_plan                IN ta_not_mov_push.plan%TYPE,
                                                p_nro_cuotas          IN ta_not_mov_push.nro_cuotas%TYPE,
                                                p_tas_interes         IN ta_not_mov_push.tas_interes%TYPE,
                                                p_cod_diferimiento    IN ta_not_mov_push.cod_diferimiento%TYPE,
                                                p_fec_diferimiento    IN ta_not_mov_push.fec_diferimiento%TYPE,
                                                p_id_int_comercio     IN ta_not_mov_push.id_int_comercio%TYPE,
                                                p_est_int_comercio    IN ta_not_mov_push.est_int_comercio%TYPE,
                                                p_cod_iso             IN ta_not_mov_push.cod_iso%TYPE,
                                                p_des_iso             IN ta_not_mov_push.cod_iso%TYPE,
                                                p_ica                 IN ta_not_mov_push.ica%TYPE,
                                                p_mcc                 IN ta_not_mov_push.ica%TYPE,
                                                p_tcc                 IN ta_not_mov_push.ica%TYPE,
                                                p_tip_estado          IN ta_not_mov_push.tip_estado%TYPE,
                                                p_cod_estado          IN ta_not_mov_push.cod_estado%TYPE,
                                                p_fec_estado          IN ta_not_mov_push.fec_estado%TYPE,
                                                p_es_forzada          IN ta_not_mov_push.es_forzada%TYPE,
                                                p_moneda              IN ta_not_mov_push.moneda%TYPE,
                                                p_imp_autorizacion    IN ta_not_mov_push.imp_autorizacion%TYPE,
                                                p_imp_tot_transaccion IN ta_not_mov_push.imp_tot_transaccion%TYPE,
                                                p_imp_convertido      IN ta_not_mov_push.imp_convertido%TYPE,
                                                p_imp_interes         IN ta_not_mov_push.imp_interes%TYPE,
                                                p_imp_int_iva         IN ta_not_mov_push.imp_int_iva%TYPE,
                                                p_imp_cargos          IN ta_not_mov_push.imp_cargos%TYPE,
                                                p_imp_car_iva         IN ta_not_mov_push.imp_car_iva%TYPE,
                                                p_imp_car_rg4240      in ta_not_mov_push.imp_car_rg4240%TYPE,
                                                p_cod_mon_ori_iso     in ta_not_mov_push.cod_mon_ori_iso%TYPE,
                                                p_imp_tot_ori_iso     in ta_not_mov_push.imp_tot_ori_iso%TYPE,
                                                p_cod_autorizacion    in ta_not_mov_push.cod_autorizacion%TYPE,
                                                p_cup_autorizacion    in ta_not_mov_push.cup_autorizacion%TYPE,
                                                p_lot_autorizacion    in ta_not_mov_push.lot_autorizacion%TYPE,
                                                p_nro_autorizacion    in ta_not_mov_push.nro_autorizacion%TYPE,
                                                p_mot_rechazo         in ta_not_mov_push.mot_rechazo%TYPE,
                                                p_des_rechazo         in ta_not_mov_push.des_rechazo%TYPE,
                                                p_nor_fra_rechazo     in ta_not_mov_push.nor_fra_rechazo%TYPE,
                                                p_reg_fra_rechazo     in ta_not_mov_push.reg_fra_rechazo%TYPE,
                                                p_cod_billetera       in ta_not_mov_push.cod_billetera%TYPE DEFAULT NULL,
                                                p_etiquetas           in ta_not_mov_push.etiquetas%TYPE DEFAULT NULL,
                                                p_cod_mensaje         OUT NUMBER,
                                                p_mensaje             OUT VARCHAR2) IS
  v_existe       VARCHAR2(1);
  r_log          ta_logs_gp%ROWTYPE;
  v_cod_correcto NUMBER := 0;
  v_cod_ent_procesadora ah_tar_debitos.cod_ent_procesadora%type:=fug_obt_pardinamico('COD_ENT_GLOBAL');

BEGIN
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
    PAE_CNF.G_PROGRAMA := 'GPPROFIN';
  End;
  r_log.nom_proceso := 'PRT_INS_NOT_PUSH';
  r_log.fec_hor_ini := SYSDATE;
  p_cod_mensaje     := v_cod_correcto;

  /*Verificamos que la cuenta recibida exista,incluimos credito y debito */
  BEGIN
      SELECT distinct 'S'
       INTO v_existe
       FROM ta_cta_tarjetas t, ta_tipos p
       WHERE t.nro_cuenta = p_nro_cuenta
       AND t.estado != 'C'
       AND t.cod_modalidad = p.cod_modalidad
       AND p.cod_ent_procesadora = v_cod_ent_procesadora;
  EXCEPTION
    WHEN no_data_found THEN
        BEGIN
          select distinct 'S'
          into v_existe
          from ah_tar_debitos s
          where s.cod_ent_procesadora = v_cod_ent_procesadora
          and tar_activa='S'
          and s.nro_cta_global=p_nro_cuenta;
        EXCEPTION
          when no_data_found then
            v_existe         := 'N';
            p_cod_mensaje    := 666;
            p_mensaje        := 'La cuenta ' || p_nro_cuenta || ' no existe.';
            r_log.comentario := substr('Cuenta  ' || p_nro_cuenta || ' no existe.',1,100);
            pat_igp.pr_ins_log(r_log);
            when others then
            v_existe         := 'N';
            p_cod_mensaje    := 666;
            p_mensaje        := 'Error al buscar la cuenta ' || p_nro_cuenta;
            r_log.comentario := substr('Error al buscar la cuenta  ' || p_nro_cuenta||'-'||
                                  SQLERRM,1,100);
            pat_igp.pr_ins_log(r_log);
        END;
    WHEN OTHERS THEN
      v_existe         := 'N';
      p_cod_mensaje    := 666;
      p_mensaje        := 'Error al buscar la cuenta ' || p_nro_cuenta;
      r_log.comentario := substr('Error al buscar la cuenta  ' || p_nro_cuenta||'-'||
                          SQLERRM,1,100);
      pat_igp.pr_ins_log(r_log);
  END;
  IF v_existe = 'S' THEN
    v_existe := 'N';
    /*Verificamos que la notificacion no se encuentre registrada*/
    BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ta_not_mov_push
       WHERE id_transaccion = p_id_transaccion
         AND id_novedad = p_id_novedad;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
       WHEN others THEN
        v_existe := 'N';
    END;
    IF v_existe = 'S' THEN
      p_cod_mensaje    := 777;
      p_mensaje        := 'La Transaccion nro. ' || p_id_transaccion || ' - ' || 'Novedad: ' || p_id_novedad || ' ' ||
                          ' ya existe.';
      r_log.comentario := 'La Transaccion nro. ' || p_id_transaccion || ' - ' || 'Novedad: ' || p_id_novedad || ' ' ||
                          ' ya existe.';
      pat_igp.pr_ins_log(r_log);
    END IF;
    IF v_existe = 'N' THEN
      /*Insertamos la notificacion*/
      BEGIN
        insert into it.ta_not_mov_push
          (id_novedad,
           tip_accion,
           id_transaccion,
           fec_hor_transaccion,
           reason,
           marca,
           entidad,
           nro_cuenta,
           cod_producto,
           afinidad,
           adicional,
           nro_tarjeta,
           provincia,
           cod_provincia,
           via_origen,
           red_origen,
           pos_origen,
           ing_origen,
           deb_automatico,
           ori_internacional,
           cod_concepto,
           plan,
           nro_cuotas,
           tas_interes,
           cod_diferimiento,
           fec_diferimiento,
           id_int_comercio,
           est_int_comercio,
           cod_iso,
           des_iso,
           ica,
           mcc,
           tcc,
           tip_estado,
           cod_estado,
           fec_estado,
           es_forzada,
           moneda,
           imp_autorizacion,
           imp_tot_transaccion,
           imp_convertido,
           imp_interes,
           imp_int_iva,
           imp_cargos,
           imp_car_iva,
           imp_car_rg4240,
           cod_mon_ori_iso,
           imp_tot_ori_iso,
           cod_autorizacion,
           cup_autorizacion,
           lot_autorizacion,
           nro_autorizacion,
           mot_rechazo,
           des_rechazo,
           nor_fra_rechazo,
           reg_fra_rechazo,
           cod_billetera,
           etiquetas)
        values
          (p_id_novedad,
           p_tip_accion,
           p_id_transaccion,
           p_fec_hor_transaccion,
           p_reason,
           p_marca,
           p_entidad,
           p_nro_cuenta,
           p_cod_producto,
           p_afinidad,
           p_adicional,
           p_nro_tarjeta,
           p_provincia,
           p_cod_provincia,
           p_via_origen,
           p_red_origen,
           p_pos_origen,
           p_ing_origen,
           p_deb_automatico,
           p_ori_internacional,
           p_cod_concepto,
           p_plan,
           p_nro_cuotas,
           p_tas_interes,
           p_cod_diferimiento,
           p_fec_diferimiento,
           p_id_int_comercio,
           p_est_int_comercio,
           p_cod_iso,
           p_des_iso,
           p_ica,
           p_mcc,
           p_tcc,
           p_tip_estado,
           p_cod_estado,
           p_fec_estado,
           p_es_forzada,
           p_moneda,
           p_imp_autorizacion,
           p_imp_tot_transaccion,
           p_imp_convertido,
           p_imp_interes,
           p_imp_int_iva,
           p_imp_cargos,
           p_imp_car_iva,
           p_imp_car_rg4240,
           p_cod_mon_ori_iso,
           p_imp_tot_ori_iso,
           p_cod_autorizacion,
           p_cup_autorizacion,
           p_lot_autorizacion,
           p_nro_autorizacion,
           p_mot_rechazo,
           p_des_rechazo,
           p_nor_fra_rechazo,
           p_reg_fra_rechazo,
           p_cod_billetera,
           p_etiquetas);
           commit;
      EXCEPTION
        WHEN OTHERS THEN
          p_cod_mensaje    := 999;
          p_mensaje        := 'Error al insertar la notificacion ' ||
                              p_id_transaccion || ' - ' || p_id_novedad || ' - ' || ' Cta.: ' ||
                              p_nro_cuenta || ' ' || SQLERRM;
          r_log.comentario := substr('Error al insertar notificacion  ' ||
                              p_id_transaccion || ' - ' || p_id_novedad || ' - ' || ' Cta.: ' ||
                              p_nro_cuenta || ' ' || SQLERRM,1,100);
          pat_igp.pr_ins_log(r_log);
      END;
    END IF;
  END IF;
  IF p_cod_mensaje = v_cod_correcto THEN
    p_mensaje := 'Notificacion ' || p_id_transaccion || ' - ' || p_id_novedad ||
                 ' ingresada con exito!';
  END IF;
END prt_ins_not_push;
/
