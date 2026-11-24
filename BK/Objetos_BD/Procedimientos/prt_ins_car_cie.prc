CREATE OR REPLACE PROCEDURE IT.prt_ins_car_cie IS
  v_lugar           VARCHAR2(50);
  v_fecha           DATE := trunc(sysdate);
  r_log             ta_logs_gp%ROWTYPE;
  v_fec_pro_arc     ta_mov_liq_cab.fec_proceso%type;
  v_fec_actual      ge_calendarios.fec_actual%TYPE;
  v_exi_arc_fecha   varchar2(1);
  v_can_reg_tmp     ta_mov_liq_res_tmp.can_reg%type;
  v_can_registros   number;
  v_error           ta_mov_liq_det.error%TYPE;
  v_cod_usuario     ba_usuarios.cod_usuario%type:=fug_obt_pardinamico('USU_AIR_T2010');--se asigna el usuario AIRFLOW al procedimiento
  v_nro_proceso     number;
  v_can_reg_det     number := 0;
  v_can_procesar    number := 5;
PROCEDURE lp_val_imp_archivo(p_nro_mov_liq ta_mov_liq_det.nro_mov_liq%type) IS
begin
  v_lugar:='Procesamiento de cabecera';
        insert into it.ta_mov_liq_cab
          (nro_mov_liq,
           tip_registro,
           cod_marca,
           cod_ent_emisora,
           gru_cierre,
           fec_cierre,
           fec_proceso,
           hor_proceso,
           archivo,
           des_archivo,
           filler)
        (select
           p_nro_mov_liq,
           c.tip_registro,
           c.cod_marca,
           c.cod_ent_emisora,
           c.gru_cierre,
           to_char(to_date(c.fec_cierre, 'yyyymmdd'), 'dd/mm/yyyy'),
           to_char(to_date(c.fec_proceso, 'yyyymmdd'), 'dd/mm/yyyy'),
           c.hor_proceso,
           c.archivo,
           c.des_archivo,
           c.filler
        from it.ta_mov_liq_cab_tmp c);
    v_lugar:='Procesamiento de resumen';
      insert into it.ta_mov_liq_res
        (nro_mov_liq, tip_registro, cod_ent_procesadora, can_reg, filler)
      (select
         p_nro_mov_liq,
         d.tip_registro,
         d.cod_ent_procesadora,
         d.can_reg,
         d.filler
      from it.ta_mov_liq_res_tmp d);
   v_lugar:='Procesamiento de detalle';
    --se carga el detalle
   begin
           INSERT INTO it.ta_mov_liq_det
                      (nro_mov_liq,
                       tip_registro,
                       nro_tarjeta,
                       cod_marca,
                       cod_ent_emisora,
                       cod_sucursal,
                       nro_cuenta,
                       tip_socio,
                       gru_cta_corriente,
                       tip_transaccion,
                       nro_comercio,
                       nom_fan_comercio,
                       cod_pos_comercio,
                       cod_autorizacion,
                       ica_adquirente,
                       cod_movimiento,
                       des_movimiento,
                       comprobante,
                       tip_plan,
                       pla_cuotas,
                       nro_cuo_vigente,
                       fec_operacion,
                       hor_operacion,
                       fec_presentacion,
                       fec_cie_cta_corriente,
                       fec_clearing,
                       fec_diferimiento,
                       mcc,
                       cod_moneda,
                       imp_mon_movimiento,
                       cod_mon_original,
                       imp_mon_original,
                       imp_interes,
                       imp_iva,
                       imp_tot_movimiento,
                       imp_des_fin_otorgado,
                       imp_des_fin_otorgado_iva,
                       imp_cuota,
                       imp_int_cuota,
                       imp_iva_cuota,
                       imp_tot_cuota,
                       debcred,
                       tip_amortizacion,
                       can_anticipada,
                       tna,
                       tea,
                       tas_intercambio,
                       ara_emisor,
                       sig_arancel,
                       iva_ara_emisor,
                       sig_iva_arancel,
                       mot_mensaje,
                       imp_compensacion,
                       sig_imp_compensacion,
                       imp_per_rg4240,
                       mon_compensacion,
                       tip_tarjeta,
                       filler,
                       procesado,
                       error
                       )
               select
                 p_nro_mov_liq,
                 t.tip_registro,
                 t.nro_tarjeta,
                 t.cod_marca,
                 t.cod_ent_emisora,
                 t.cod_sucursal,
                 to_number(t.nro_cuenta) nro_cuenta,
                 t.tip_socio,
                 t.gru_cta_corriente,
                 t.tip_transaccion,
                 t.nro_comercio,
                 t.nom_fan_comercio,
                 t.cod_pos_comercio,
                 t.cod_autorizacion,
                 t.ica_adquirente,
                 to_number(t.cod_movimiento)cod_movimiento,
                 trim(t.des_movimiento)des_movimiento,
                 to_number(t.comprobante)comprobante,
                 t.tip_plan,
                 t.pla_cuotas,
                 t.nro_cuo_vigente,
                 to_date(to_char(t.fec_operacion),'yyyy/mm/dd') fec_operacion,
                 to_char(to_date(to_char(t.hor_operacion),'hh:mm:ss'),'hh:mm:ss') hor_operacion,
                 to_date(to_char(t.fec_presentacion),'yyyy/mm/dd') fec_presentacion,
                 to_date(to_char(t.fec_cie_cta_corriente),'yyyy/mm/dd') fec_cie_cta_corriente,
                 decode(t.fec_clearing, '00000000', NULL, to_date(to_char(t.fec_clearing),'yyyy/mm/dd')) fec_clearing,
                 decode(t.fec_diferimiento, '00000000', NULL, to_date(to_char(t.fec_diferimiento),'yyyy/mm/dd')) fec_diferimiento,
                 t.mcc,
                 t.cod_moneda,
                 trunc(t.imp_mon_movimiento) imp_mon_movimiento,
                 t.cod_mon_original,
                 trunc(t.imp_mon_original) imp_mon_original,
                 trunc(t.imp_interes) imp_interes,
                 trunc(t.imp_iva) imp_iva,
                 trunc(t.imp_tot_movimiento) imp_tot_movimiento,
                 trunc(t.imp_des_fin_otorgado) imp_des_fin_otorgado,
                 trunc(t.imp_des_fin_otorgado_iva) imp_des_fin_otorgado_iva,
                 trunc(t.imp_cuota) imp_cuota,
                 trunc(t.imp_int_cuota) imp_int_cuota,
                 trunc(t.imp_iva_cuota) imp_iva_cuota,
                 trunc(t.imp_tot_cuota) imp_tot_cuota,
                 t.debcred,
                 t.tip_amortizacion,
                 t.can_anticipada,
                 t.tna,
                 t.tea,
                 t.tas_intercambio,
                 trunc(t.ara_emisor) ara_emisor,
                 t.sig_arancel,
                 trunc(t.iva_ara_emisor) iva_ara_emisor,
                 t.sig_iva_arancel,
                 t.mot_mensaje,
                 trunc(t.imp_compensacion) imp_compensacion,
                 t.sig_imp_compensacion,
                 trunc(t.imp_per_rg4240) imp_per_rg4240,
                 t.mon_compensacion,
                 t.tip_tarjeta,
                 t.filler,
                   'N',decode(
                            (select distinct '1'
                            from ta_cta_tarjetas a,ge_cta_clientes s
                            where a.nro_cuenta=s.nro_cuenta
                            and s.relacion = 'P'
                            and s.nro_cuenta=t.nro_cuenta),'1',null,'Cuenta invalida') error  
                 from it.ta_mov_liq_det_tmp t
                 where to_number(t.cod_movimiento)in
                 (select r.cod_referencia
                 from ta_ref_movimientos_gp r
                 WHERE r.ref_archivo like 'T2010S');
             exception
              WHEN OTHERS THEN
                r_log.comentario := substr('Error en importacion de detalle,lote procesado : ' || p_nro_mov_liq|| '-' ||
                                    to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                    SQLERRM,1,499);
                pat_igp.pr_ins_log(r_log);
            end;
exception
WHEN OTHERS THEN
r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || '-' ||
                    v_lugar || '-' ||
                    to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                    SQLERRM,1,499);
pat_igp.pr_ins_log(r_log);
end;
PROCEDURE pr_trg_activar(p_accion in number) is
  v_mensaje varchar2(500);
begin
  --Accion
  --0 Desactivar
  --1 Activar
    if p_accion=0 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_MOV_LIQ_DET DISABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_MOV_LIQ_DET DISABLE', v_mensaje);
    elsif p_accion=1 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_MOV_LIQ_DET ENABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_MOV_LIQ_DET ENABLE', v_mensaje);
    end if;
    if v_mensaje is not null then
      r_log.comentario:=v_mensaje;
      pat_igp.pr_ins_log(r_log);
    end if;
exception
  when others then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_MOV_LIQ_DET ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_MOV_LIQ_DET ENABLE', r_log.comentario);
      pat_igp.pr_ins_log(r_log);
end;

FUNCTION fu_obt_hora(p_ind_usuario number) return varchar2 is
    v_hora ge_movimientos.hora%type;
    v_nro_sec number;
    v_nro_hor number;
  BEGIN

    v_nro_sec := fue_obt_sig_secuencia('s_nro_hora'||p_ind_usuario);

    if v_nro_sec <= 86400 then
      v_nro_hor := v_nro_sec;
    else
      v_nro_hor := mod(v_nro_sec, 86400);
    end if;

    v_hora := TO_CHAR(trunc(v_nro_hor/3600), 'FM9900')|| ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor,3600)/60),'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor,60),'FM00');

    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'No se puede obtener la hora del movimiento. ' || sqlerrm);
  END;

PROCEDURE pr_ver_horario(p_fec_proceso IN date,
                         p_hor_proceso IN varchar2,
                         p_es_nocturno OUT VARCHAR2,
                         p_fecha out date) IS
    v_es_nocturno VARCHAR2(1) := 'N';
    v_fec_proceso ge_movimientos.fecha%TYPE;
    v_est_modulo  ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(5);
    v_hor_limite  varchar2(8) := '999999';
    v_cod_ofi_origen ge_cta_clientes.cod_oficina%type;
  BEGIN
    -- Obtiene la oficina de Casa Matriz.
    Begin
      Select cod_ofi_matriz into v_cod_ofi_origen from ge_par_generales;
    end;

    v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
    v_fec_proceso := pag_cal.fu_obt_fec_actual(5);
    p_fecha := v_fec_proceso;
    IF v_est_modulo = 2 THEN
      -- El modulo esta abierto
      -- Verifica la hora --
      IF (p_hor_proceso > v_hor_limite AND v_fec_proceso = p_fec_proceso) OR
        v_fec_proceso < p_fec_proceso THEN
        v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                  1,
                                                  v_cod_ofi_origen);
        p_fecha := v_fec_proceso;
        v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
      END IF;
    ELSE
      v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                1,
                                                v_cod_ofi_origen);
      p_fecha := v_fec_proceso;
      v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
    END IF;
    p_es_nocturno := v_es_nocturno;
  END;
  -----procedimiento para ge_movimientos
procedure prt_pro_car_cie is
  v_hora              ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_fecha             ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(5);
  v_cod_ofi_matriz    ba_oficinas.cod_oficina%TYPE;
  v_mod_con_cta       ge_movimientos.cod_modulo%TYPE;
  v_mad_con_cta       ge_movimientos.cod_modalidad%TYPE;
  v_cod_oficina_cli   ge_cta_clientes.cod_oficina%type;
  v_cod_moneda        ge_cuentas.cod_moneda%type;
  v_cod_tra_padre     ge_transacciones.cod_transaccion%TYPE;
  v_cod_tra_impuesto  ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto  ge_movimientos.cod_tasa%type;
  v_cod_tra_gravada   ge_movimientos.cod_transaccion%TYPE;
  v_es_nocturno       VARCHAR2(1) := 'N';
  r_gmovi             ge_movimientos%ROWTYPE;
  v_error             varchar2(500);
  v_val_tas_cargo     ge_movimientos.val_tasa%type;
  v_cod_usu_proceso   ba_usuarios.cod_usuario%type;
  v_ind_usuario       number;

CURSOR movs IS
select a.nro_cuenta,cod_movimiento,comprobante,fec_operacion,
imp_mon_movimiento,des_movimiento,imp_iva,rowid id_fila
from ta_mov_liq_det a
where a.error is null
and nvl(a.procesado,'N')='N'
and a.fec_proceso>fec_proceso-30;

BEGIN
  PRE_INI_APLICACION; 
  PAE_CNF.G_COD_MODULO := 1;
  Begin
      Select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
  exception
    when others then
      v_cod_ofi_matriz := 1;
  end;
  FOR c IN movs LOOP
    v_can_reg_det:=v_can_reg_det+1;
    v_error:=null;
    BEGIN
      SELECT s.cod_modulo, s.cod_modalidad, s.cod_oficina, s.cod_moneda
        INTO v_mod_con_cta, v_mad_con_cta, v_cod_oficina_cli, v_cod_moneda
        FROM ge_cuentas s
       WHERE s.nro_cuenta = c.nro_cuenta;

    EXCEPTION
      WHEN no_data_found THEN
        v_mod_con_cta := NULL;
        v_mad_con_cta := NULL;
        v_cod_oficina_cli := NULL;
        v_cod_moneda := NULL;
      WHEN OTHERS THEN
        v_error:=(' Error al obtener la cuenta '|| c.nro_cuenta);
      END;

      --***Obs. importantes
      --***El codigo de la gravada de la transaccion sera almacenado
      --en la columna cod_transaccion de la tabla ta_ref_movimientos_gp
      --***El codigo de transaccion referente al IVA se recupera de la tabla ge_transacciones_det
        begin
              SELECT r.cod_transaccion
              INTO v_cod_tra_gravada
              FROM ta_ref_movimientos_gp r
              WHERE r.cod_referencia=to_number(c.cod_movimiento)
              and r.cod_modalidad= v_mad_con_cta
              and r.procesa='S'
              and r.ref_archivo like 'T2010S';
              exception
                when no_data_found then
                  v_cod_tra_gravada:=null;
                when others then
                  v_cod_tra_gravada:=null;
         end;
         begin
           SELECT cod_tra_hijo
              INTO v_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = v_mod_con_cta
               AND cod_modalidad = v_mad_con_cta
               AND cod_transaccion = v_cod_tra_gravada;
                   exception
                when no_data_found then
                  v_cod_tra_impuesto:=null;
                when others then
                  v_cod_tra_impuesto:=null;
          end;

        IF c.cod_movimiento = 82 THEN
          v_cod_tra_padre    := '1215';
        ELSIF c.cod_movimiento = 123 THEN
          v_cod_tra_padre    := '20';
        ELSIF c.cod_movimiento IN (708,709,785) THEN
          v_cod_tra_padre    := '1214';
        else
          v_cod_tra_padre    := '38';
        END IF;

      IF v_mod_con_cta IS NOT NULL and v_cod_tra_gravada is not null THEN
        r_gmovi := NULL;
        ---------------
        v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
        v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
        v_hora              := fu_obt_hora(v_ind_usuario);
        pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
        ---------------
        --IMPORTE
        r_gmovi.cod_modulo      := v_mod_con_cta;
        r_gmovi.cod_modalidad   := v_mad_con_cta;
        r_gmovi.cod_oficina     := v_cod_oficina_cli;
        r_gmovi.nro_cuenta      := c.nro_cuenta;
        r_gmovi.nro_documento   := c.comprobante;
        r_gmovi.cod_rubro       := '';
        r_gmovi.tip_mov_rubro   := '';
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_usuario     := v_cod_usu_proceso;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.nro_secuencia   := '1';
        r_gmovi.fec_valor       := c.fec_operacion;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_mod_con_cta;
        r_gmovi.cod_mad_padre   := v_mad_con_cta;
        r_gmovi.cod_transaccion := v_cod_tra_gravada;
        begin
        r_gmovi.cod_persona     := it.fug_obt_cli_principal(c.nro_cuenta);
        exception
          when others then
            r_gmovi.cod_persona     :=null;
        end;
        r_gmovi.monto           := trunc(c.imp_mon_movimiento);
        r_gmovi.cod_tasa        := NULL;
        r_gmovi.val_tasa        := NULL;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := v_cod_ofi_matriz;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := upper(c.des_movimiento);
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        BEGIN
          if trunc(c.imp_mon_movimiento)>0 then
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
          end if;
        EXCEPTION
          WHEN OTHERS THEN
             begin
               v_cod_usu_proceso       := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
               v_ind_usuario           := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
               v_hora                  := fu_obt_hora(v_ind_usuario);
               pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
               r_gmovi.hora            := v_hora;
               r_gmovi.cod_usuario     := v_cod_usu_proceso;
               pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
             exception
               when others then
                 begin
                 v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                 v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                 v_hora              := fu_obt_hora(v_ind_usuario);
                 pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                 r_gmovi.hora            := v_hora;
                 r_gmovi.cod_usuario     := v_cod_usu_proceso;
                 pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                 exception
                   when others then
                     begin
                       v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                       v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                       v_hora              := fu_obt_hora(v_ind_usuario);
                       pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                       r_gmovi.hora            := v_hora;
                       r_gmovi.cod_usuario     := v_cod_usu_proceso;
                       pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                    exception
                   when others then
                       begin
                         v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                         v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                         v_hora              := fu_obt_hora(v_ind_usuario);
                         pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                         r_gmovi.hora            := v_hora;
                         r_gmovi.cod_usuario     := v_cod_usu_proceso;
                         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                      exception
                     when others then
                         begin
                           v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                           v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                           v_hora              := fu_obt_hora(v_ind_usuario);
                           pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                           r_gmovi.hora            := v_hora;
                           r_gmovi.cod_usuario     := v_cod_usu_proceso;
                           pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                        exception
                       when others then  
                           begin
                             v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                             v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                             v_hora              := fu_obt_hora(v_ind_usuario);
                             pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                             r_gmovi.hora            := v_hora;
                             r_gmovi.cod_usuario     := v_cod_usu_proceso;
                             pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
                          exception
                         when others then  
                          v_error:=substr(('Error en el Importe grav.: ' || SQLERRM || ' ' ||c.nro_cuenta),1,499);
                          end;
                        end;
                      end;
                    end;
                 end;
              end;
        END;
        r_gmovi := NULL;              
        if v_error is null then
        --IMPORTE IVA
        --Busco el cod_tasa y val_tasa para el iva
        begin
        SELECT a.cod_tasa, c.val_tasa
          INTO v_cod_tas_impuesto, v_val_tas_cargo
          FROM ge_transacciones a, ge_tasas b, ge_tas_fechas c
         WHERE a.cod_tasa = b.cod_tasa
           AND b.cod_tasa = c.cod_tasa
           AND c.cod_moneda = v_cod_moneda
           AND a.cod_transaccion = v_cod_tra_impuesto
           AND a.cod_modalidad = v_mad_con_cta
           AND c.fec_vigencia = (SELECT MAX(x.fec_vigencia)
                                   FROM ge_tas_fechas x
                                  WHERE x.cod_tasa = c.cod_tasa
                                    AND x.cod_moneda = v_cod_moneda);
       exception
          when others then
            v_cod_tas_impuesto:=null;
            v_error:= substr(v_error||('Error al recuperar IVA .: ' || SQLERRM || ' ' ||c.nro_cuenta),1,499);
       end;

        r_gmovi.cod_modulo      := v_mod_con_cta;
        r_gmovi.cod_modalidad   := v_mad_con_cta;
        r_gmovi.cod_oficina     := v_cod_oficina_cli;
        r_gmovi.nro_cuenta      := c.nro_cuenta;
        r_gmovi.cod_rubro       := '';
        r_gmovi.tip_mov_rubro   := '';
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.nro_documento   := c.comprobante;
        r_gmovi.cod_usuario     := v_cod_usu_proceso;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.nro_secuencia   := '2';
        r_gmovi.fec_valor       := c.fec_operacion;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_mod_con_cta;
        r_gmovi.cod_mad_padre   := v_mad_con_cta;
        r_gmovi.cod_transaccion := v_cod_tra_impuesto;
        begin
        r_gmovi.cod_persona     := it.fug_obt_cli_principal(c.nro_cuenta);
        exception
          when others then
            r_gmovi.cod_persona     :=null;
        end;
        r_gmovi.monto           := trunc(c.imp_iva);
        r_gmovi.cod_tasa        := v_cod_tas_impuesto;
        r_gmovi.val_tasa        := v_val_tas_cargo;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := v_cod_ofi_matriz;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := upper(c.des_movimiento);
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        BEGIN
          if trunc(c.imp_iva)>0 and v_cod_tas_impuesto is not null then
             pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
          end if;
        EXCEPTION
          WHEN OTHERS THEN
                 v_error:=substr(('.Error en Iva: ' || SQLERRM || ' ' ||c.nro_cuenta),1,499);
        END;
       end if;
        if v_error is not null then
            r_log.fec_hor_ini := SYSDATE;
            r_log.nom_proceso    :='PRT_INS_CAR_CIE';
            r_log.comentario := substr(v_error,1,499);
            pat_igp.pr_ins_log(r_log);
            begin
                update ta_mov_liq_det s
                set error=substr(v_error,1,499)
                where rowid=c.id_fila;
            end;
        else
          begin
            update ta_mov_liq_det s
            set s.procesado='S'
            where rowid=c.id_fila;
          end;
        end if;
    ELSE
      begin
        update ta_mov_liq_det s
        set error=substr(v_error||'.'||'No se encontro gravada',1,499)
        where rowid=c.id_fila;
       end;
    END IF;
    IF MOD(v_can_reg_det, v_can_procesar) = 0 THEN
         commit;
    END IF;
  END LOOP;
     -- Confirmar transacción final
     commit;
EXCEPTION
  WHEN OTHERS THEN
    r_log.comentario := substr('Error en prt_pro_car_cie : ' || r_log.nom_proceso  || '-' ||
                    to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                    SQLERRM,1,499);
    pat_igp.pr_ins_log(r_log);
END;

BEGIN
  /*Setear valores-llamar procedimiento de ta_logs de inicio de proceso*/
  IT.PRE_INI_APLICACION;
  v_fec_actual := pag_cal.fu_obt_fec_actual(5);
  pae_cnf.g_cod_modulo := 1;
  r_log.nom_proceso    := 'PRT_INS_CAR_CIE';
  r_log.fec_hor_ini    := SYSDATE;
  r_log.comentario     := '*** Inicio proceso de registro de intereses y cargos T2010S ***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Deshabilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(0);
  --validaciones para la importacion de registros
  --Recuperamos fecha de cabecera del temporal
  begin
    select to_char(to_date(fec_proceso,'yyyy/mm/dd'),'dd/mm/yyyy')--fec_proceso
      into v_fec_pro_arc
      from ta_mov_liq_cab_tmp;
  exception
    when others THEN
      r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'al buscar la cabecera del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000, 'Error al buscar la cabecera del archivo. '||sqlerrm);
  end;
  --Recuperamos misma fecha del maestro
  begin
    select distinct 'S'
      into v_exi_arc_fecha
      from it.ta_mov_liq_cab t
     where t.fec_proceso = v_fec_pro_arc;
  exception
    when others then
      v_exi_arc_fecha := 'N';
  end;
  --Validamos que la fecha del temporal no exista en el maestro

  if nvl(v_exi_arc_fecha, 'N')= 'S' THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'El archivo T2010 ya fue conciliado'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
    r_log.men_error:='El archivo T2010 ya fue conciliado.';
    r_log.nro_error:='-20000';
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Error,el archivo T2010 ya fue conciliado. '||sqlerrm);
  end if;
  -----------------
  --Recuperamos la cantidad de registros del detalle del temporal
  begin
    select count(*)
      into v_can_reg_tmp
      from ta_mov_liq_det_tmp;
  exception
    when others then
      v_can_reg_tmp := 0;
  end;
  --Recuperamos la cantidad de registros situada en el resumen del temporal
  begin
    select c.can_reg
      into v_can_registros
      from ta_mov_liq_res_tmp c;
  exception
    when others THEN
      r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'Error al buscar el resumen del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000,'Error al buscar el resumen del archivo. '||sqlerrm);
  end;
  --Validamos que coincidan la cantidad de registros
  if nvl(v_can_registros, 0) <> nvl(v_can_reg_tmp, 0) THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'Cantidad de Detalle no coincide con el resumen'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Cantidad de Detalle no coincide con el resumen.');
  end if;


  --Recuperamos la secuencia para el procesamiento de los registros
  BEGIN
    select it.S_NRO_mov_liq_GP.nextval
      into v_nro_proceso
      from dual;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al obtener el nro. de secuencia. ' || sqlerrm);
  END;
  --Se realiza la importacion del temporal al maestro
  lp_val_imp_archivo(v_nro_proceso);
  commit;
  --Se realiza el procesamiento de los registros e insercion en ge_movimientos
  prt_pro_car_cie();
  commit;
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de registro de intereses y cargos T2010S***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Habilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(1);
EXCEPTION
WHEN OTHERS THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
    pat_igp.pr_ins_log(r_log);
    prg_ins_log_programas('PRT_INS_CAR_CIE',substr(sqlerrm,1,4000));
    pr_trg_activar(1);
END;
/
