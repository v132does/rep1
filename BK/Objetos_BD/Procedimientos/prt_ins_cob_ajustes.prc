CREATE OR REPLACE PROCEDURE IT.prt_ins_cob_ajustes IS
  v_lugar            VARCHAR2(50);
  v_fecha            DATE := trunc(sysdate);
  r_log              ta_logs_gp%ROWTYPE;
  v_fec_actual       ge_calendarios.fec_actual%TYPE;
  v_exi_arc_fecha    varchar2(1);
  v_can_registros    number;
  v_cod_ent_procesadora varchar2(10):=fug_obt_pardinamico('COD_ENT_GLOBAL');
  v_cod_usuario      ba_usuarios.cod_usuario%type:=fug_obt_pardinamico('USU_AIR_T3022');--se asigna el usuario AIRFLOW al procedimiento 
  v_error            ta_cob_ajustes.error%TYPE;
  v_importe_gravada  ge_movimientos.monto%TYPE;
  v_importe_impuesto ge_movimientos.monto%TYPE;
  v_nro_cob_dia      ta_cob_ajustes_cab.nro_cob_dia%TYPE;
  v_fec_pro_arc      ta_cob_ajustes_cab.fec_proceso%TYPE;
  v_can_reg_tmp      ta_cob_ajustes_res.can_registros%TYPE;
  v_can_reg_det      number := 0;
  v_can_procesar     number := 5;
  v_nom_programa      VARCHAR2(50) := 'PRT_INS_COB_AJUSTES';

PROCEDURE lp_val_imp_archivo(p_nro_cob_dia ta_cob_ajustes_cab.nro_cob_dia%TYPE) IS
BEGIN
    v_lugar := 'Insert ta_cob_ajustes_cab ';
      INSERT INTO it.ta_cob_ajustes_cab
        (nro_cob_dia,
         tip_registro,
         cod_ent_emisora,
         cod_marca,
         cod_ide_archivo,
         des_archivo,
         fec_proceso,
         hor_proceso,
         filler)
        SELECT p_nro_cob_dia,
         c.tip_registro,
         c.cod_ent_emisora,
         c.cod_marca,
         c.cod_ide_archivo,
         c.des_archivo,
         to_char(to_date(c.fec_proceso, 'yyyymmdd'), 'dd/mm/yyyy'),
         c.hor_proceso,
         c.filler
	       FROM it.ta_cob_ajustes_cab_tmp c;
     v_lugar := 'Insert resumen';
      INSERT INTO it.ta_cob_ajustes_res
        (nro_cob_dia,
         tip_registro,
         cod_ent_emisora,
         cod_ide_archivo,
         can_registros,
         filler)
       SELECT p_nro_cob_dia,
              r.tip_registro,
              r.cod_ent_emisora,
              r.cod_ide_archivo,
              r.can_registros,
              r.filler
         FROM it.ta_cob_ajustes_res_tmp r;
    v_lugar := 'Insert detalle';
    INSERT INTO ta_cob_ajustes
             (tip_registro,
              tip_operacion,
              ent_emisora,
              suc_ent_emisora,
              ent_cobradora,
              suc_ent_cobradora,
              cod_moneda,
              nro_comprobante,
              fec_movimiento,
              nro_cuenta,
              importe,
              concepto,
              tip_movimiento,
              fec_presentacion,
              fec_aplicacion,
              fec_cierre_cta_cte,
              ori_cob_ajuste,
              nro_envio,
              gru_cta_cte_socio,
              cod_error,
              desc_error,
              cod_producto,
              nro_caja,
              usuario,
              filler,
              fec_proceso,
              procesado,
              error)
              select
              i.tip_registro,
              i.tip_operacion,
              i.ent_emisora,
              i.suc_ent_emisora,
              i.ent_cobradora,
              i.suc_ent_cobradora,
              i.cod_moneda,
              i.nro_comprobante,
              i.fec_movimiento,
              i.nro_cuenta,
              i.importe,
              i.concepto,
              i.tip_movimiento,
              i.fec_presentacion,
              i.fec_aplicacion,
              i.fec_cierre_cta_cte,
              i.ori_cob_ajuste,
              i.nro_envio,
              i.gru_cta_cte_socio,
              i.cod_error,
              i.desc_error,
              i.cod_producto,
              i.nro_caja,
              i.usuario,
              i.filler,
              v_fecha,
              'N',
              decode(
                    (select distinct '1'
                    from ta_cta_tarjetas a,ge_cta_clientes s
                    where a.nro_cuenta=s.nro_cuenta
                    and s.relacion = 'P'
                    and s.nro_cuenta=to_char(i.nro_cuenta)),'1',null,'Cuenta invalida') error  
              from it.ta_cob_ajustes_tmp i
              where i.cod_producto in (select ref_externa from ta_tipos p
                                       where p.cod_ent_procesadora=v_cod_ent_procesadora);
              commit;
    v_lugar := 'Update detalle';
                update it.ta_cob_ajustes r
                set error=error||'-No se encuentra movimiento'
                WHERE trunc(r.fec_insercion)=trunc(sysdate)
                and r.cod_producto in (select ref_externa from ta_tipos p
                            where p.cod_ent_procesadora=v_cod_ent_procesadora)
                and decode(tip_operacion,1,3,2,r.concepto) not in
                (select to_number(cod_referencia)
                FROM ta_ref_movimientos_gp rf
                WHERE rf.ref_archivo = 'T3022D'
                );
    COMMIT;
  EXCEPTION
      WHEN OTHERS THEN
        r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || '-' ||
                                    v_lugar || '-' ||
                                    to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                    SQLERRM,1,499);
        pat_igp.pr_ins_log(r_log);
END;

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

PROCEDURE pr_calc_montos(p_monto        IN NUMBER,
                         p_val_tasa     IN NUMBER,
                         p_imp_gravada  OUT NUMBER,
                         p_imp_impuesto OUT NUMBER) IS
BEGIN
  BEGIN
    SELECT trunc(round(p_monto/((100+p_val_tasa)/100))) gravada,
           trunc(round((p_val_tasa/100)*(p_monto/((100+p_val_tasa)/100)))) impuesto
      INTO p_imp_gravada, p_imp_impuesto
      FROM dual;
  EXCEPTION
    WHEN OTHERS THEN
      p_imp_gravada  := NULL;
      p_imp_impuesto := NULL;
  END;
END;

PROCEDURE pr_ver_horario(p_fec_proceso IN date,
                           p_hor_proceso IN varchar2,
                           p_es_nocturno OUT VARCHAR2,
                           p_fecha out date ) IS
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
PROCEDURE pr_trg_activar(p_accion in number) is
  v_mensaje varchar2(500);
begin
  --Accion
  --0 Desactivar
  --1 Activar
    if p_accion=0 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_COB_AJUSTES DISABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_COB_AJUSTES DISABLE', v_mensaje);
    elsif p_accion=1 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_COB_AJUSTES ENABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_COB_AJUSTES ENABLE', v_mensaje);
    end if;
    if v_mensaje is not null then
      r_log.comentario:=v_mensaje;
      pat_igp.pr_ins_log(r_log);
    end if;
exception
  when others then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_COB_AJUSTES ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_COB_AJUSTES ENABLE', r_log.comentario);
      pat_igp.pr_ins_log(r_log);
end;
PROCEDURE prt_pro_car_cie IS
v_hora              ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,'HH24:MI:SS');
v_fecha             ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(5);
v_cod_ofi_matriz    ba_oficinas.cod_oficina%TYPE;
v_mod_con_cta       ge_movimientos.cod_modulo%TYPE;
v_mad_con_cta       ge_movimientos.cod_modalidad%TYPE;
v_cod_oficina_cli   ge_cta_clientes.cod_oficina%type;
v_cod_moneda        ge_cuentas.cod_moneda%type;
v_cod_tra_padre     ge_transacciones.cod_transaccion%TYPE:=38;
v_cod_tra_impuesto  ge_movimientos.cod_transaccion%type;
v_cod_tas_impuesto  ge_movimientos.cod_tasa%type;
v_cod_tra_gravada   ge_movimientos.cod_transaccion%TYPE;
v_es_nocturno       VARCHAR2(1) := 'N';
r_gmovi             ge_movimientos%ROWTYPE;
v_error             varchar2(500);
v_val_tas_cargo     ge_movimientos.val_tasa%type;
v_concepto          ge_movimientos.concepto%TYPE;
v_ent_emisora       ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_PRO_GLOBAL');
v_cod_usu_proceso   ba_usuarios.cod_usuario%type;
v_ind_usuario       number;

CURSOR movs IS
  SELECT nro_cuenta,cod_producto,concepto,tip_operacion,
  importe,nro_comprobante,fec_movimiento,rowid id_fila
    FROM ta_cob_ajustes a
   WHERE nvl(a.cod_error,0) = 0
     AND a.error IS NULL
     AND nvl(a.procesado,'N') = 'N'
     and a.cod_producto in (select ref_externa from ta_tipos p
                            where p.cod_ent_procesadora=v_cod_ent_procesadora)
     and a.fec_proceso>= a.fec_proceso-30
     and a.ent_emisora= v_ent_emisora;


BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
  BEGIN
    SELECT cod_ofi_matriz
      INTO v_cod_ofi_matriz
      FROM ge_par_generales;
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_ofi_matriz := 1;
  END;
  FOR c IN movs LOOP
    v_can_reg_det:=v_can_reg_det+1;
    v_error := NULL;
    BEGIN
      SELECT s.cod_modulo, s.cod_modalidad, s.cod_oficina, s.cod_moneda
        INTO v_mod_con_cta, v_mad_con_cta, v_cod_oficina_cli, v_cod_moneda
        FROM ge_cuentas s
       WHERE s.nro_cuenta = c.nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        v_mod_con_cta     := NULL;
        v_mad_con_cta     := NULL;
        v_cod_oficina_cli := NULL;
        v_cod_moneda      := NULL;
    END;

    /****Obs. importantes***
    - El codigo de la gravada de la transaccion sera almacenado
      en la columna cod_transaccion de la tabla ta_ref_movimientos_gp.
    - El codigo de transaccion referente al IVA se recupera de la tabla ge_transacciones_det*/

    /*Verifica si el movimiento se trata de un pago o un cargo: 1-Pago/2-Cargo*/
      BEGIN
        SELECT r.cod_transaccion, r.descripcion
          INTO v_cod_tra_gravada, v_concepto
          FROM ta_ref_movimientos_gp r
         WHERE r.cod_referencia = decode(c.tip_operacion,1,3,2,c.concepto)
         and r.cod_modalidad=v_mad_con_cta
         and procesa='S'
         AND  r.ref_archivo='T3022D';
         IF c.tip_operacion = 1 THEN
           /*Pagos no tiene IVA, asigno el importe del archivo*/
           v_importe_gravada := c.importe;
         END IF;
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_tra_gravada:= NULL;
        WHEN OTHERS THEN
          v_cod_tra_gravada:= NULL;
      END;
      
      IF v_cod_tra_gravada IS NOT NULL THEN
       BEGIN
          SELECT cod_tra_hijo
            INTO v_cod_tra_impuesto
            FROM ge_transacciones_det
           WHERE cod_modulo = v_mod_con_cta
             AND cod_modalidad = v_mad_con_cta
             AND cod_transaccion = v_cod_tra_gravada;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_tra_impuesto:= NULL;
          WHEN OTHERS THEN
            v_cod_tra_impuesto:= NULL;
        END;
      END IF;
    --end if;
    -------
    /*Transaccion del Impuesto*/
    if c.tip_operacion <> 1 and v_cod_tra_impuesto is not null then
        BEGIN
          SELECT a.cod_transaccion,a.cod_tasa,c.val_tasa
            INTO v_cod_tra_impuesto,v_cod_tas_impuesto, v_val_tas_cargo
            FROM ge_transacciones a, ge_tasas b, ge_tas_fechas c
           WHERE a.cod_tasa = b.cod_tasa
             AND b.cod_tasa = c.cod_tasa
             AND c.cod_moneda = v_cod_moneda
             AND a.cod_transaccion =
                 (SELECT cod_tra_hijo
                    FROM ge_transacciones_det
                   WHERE cod_modulo = v_mod_con_cta
                     AND cod_modalidad = v_mad_con_cta
                     AND cod_transaccion = v_cod_tra_gravada)
             AND a.cod_modalidad = v_mad_con_cta
             AND c.fec_vigencia = (SELECT MAX(x.fec_vigencia)
                                     FROM ge_tas_fechas x
                                    WHERE x.cod_tasa = c.cod_tasa
                                      AND x.cod_moneda = v_cod_moneda);
          pr_calc_montos(c.importe,v_val_tas_cargo,v_importe_gravada,v_importe_impuesto);
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_tra_impuesto := NULL;
            v_importe_gravada  := c.importe;
            v_importe_impuesto := NULL;
          WHEN OTHERS THEN
            v_importe_gravada  := NULL;
            v_cod_tra_impuesto := NULL;
            v_importe_impuesto := NULL;
        END;
    else
      v_importe_gravada := c.importe;
    end if;

      /*Inserta el movimiento*/
    IF v_mod_con_cta IS NOT NULL AND v_cod_tra_gravada IS NOT NULL THEN
      v_lugar := 'Inserta movimiento gravado ' || c.nro_cuenta;
       r_gmovi := NULL;
       ----------------------------------------------------------------------------------------------------------
        v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
        v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
        v_hora              := fu_obt_hora(v_ind_usuario);
        pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
       ----------------------------------------------------------------------------------------------------------
      --GRAVADA
      r_gmovi.cod_modulo      := v_mod_con_cta;
      r_gmovi.cod_modalidad   := v_mad_con_cta;
      r_gmovi.cod_oficina     := v_cod_oficina_cli;
      r_gmovi.nro_cuenta      := c.nro_cuenta;
      r_gmovi.cod_transaccion := NULL;
      r_gmovi.nro_documento   := c.nro_comprobante;
      r_gmovi.cod_rubro       := '';
      r_gmovi.tip_mov_rubro   := '';
      r_gmovi.cod_moneda      := v_cod_moneda;
      r_gmovi.cod_usuario     := v_cod_usu_proceso;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.nro_secuencia   := '1';
      r_gmovi.fec_valor       := c.fec_movimiento;
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
      r_gmovi.monto           := v_importe_gravada;
      r_gmovi.cod_tasa        := NULL;
      r_gmovi.val_tasa        := NULL;
      r_gmovi.cotizacion      := NULL;
      r_gmovi.cod_ofi_origen  := v_cod_ofi_matriz;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := v_concepto;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      BEGIN
        IF v_importe_gravada > 0 THEN
          pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
        END IF;
      EXCEPTION
          WHEN OTHERS THEN
            begin
                   v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
                   v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
                   v_hora              := fu_obt_hora(v_ind_usuario);
                   pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                   r_gmovi.hora            := v_hora;
                   r_gmovi.cod_usuario     := v_cod_usu_proceso;
              pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
             EXCEPTION
                WHEN OTHERS THEN
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

      /*IMPORTE IVA*/
      IF v_cod_tra_impuesto IS NOT NULL and v_error is null THEN
        v_lugar:= 'Inserta movimiento IVA ' || c.nro_cuenta;
        r_gmovi.cod_modulo      := v_mod_con_cta;
        r_gmovi.cod_modalidad   := v_mad_con_cta;
        r_gmovi.cod_oficina     := v_cod_oficina_cli;
        r_gmovi.nro_cuenta      := c.nro_cuenta;
        r_gmovi.cod_rubro       := '';
        r_gmovi.tip_mov_rubro   := '';
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.nro_documento   := c.nro_Comprobante;
        r_gmovi.cod_usuario     := v_cod_usu_proceso;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.nro_secuencia   := '2';
        r_gmovi.fec_valor       := c.fec_movimiento;
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
        r_gmovi.monto           := v_importe_impuesto;
        r_gmovi.cod_tasa        := v_cod_tas_impuesto;
        r_gmovi.val_tasa        := v_val_tas_cargo;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := v_cod_ofi_matriz;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := v_concepto;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';

        BEGIN
          IF v_importe_impuesto > 0 AND v_cod_tas_impuesto IS NOT NULL THEN
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
          END IF;
        EXCEPTION
        WHEN OTHERS THEN
          v_error:=('Error en importe IVA: ' || SQLERRM || ' ' || c.nro_cuenta);
        END;
      END IF;

      IF v_error IS NOT NULL THEN
        r_log.fec_hor_ini := SYSDATE;
        r_log.nom_proceso := v_nom_programa;
        r_log.comentario  := c.nro_cuenta || ' ' || substr(v_error,1,400);
        pat_igp.pr_ins_log(r_log);
        BEGIN
          UPDATE ta_cob_ajustes s
             SET error = substr(v_error,1,499)
           WHERE rowid = c.id_fila;
        END;
      ELSE
        BEGIN
          UPDATE ta_cob_ajustes s
             SET s.procesado = 'S'
           WHERE rowid = c.id_fila;
        END;
      END IF;
    ELSE
      --No se encontro mod. cta o gravada
      BEGIN
          UPDATE ta_cob_ajustes s
             SET error = substr(v_error,1,499)
           WHERE rowid = c.id_fila;
      END;
    END IF;
    IF MOD(v_can_reg_det, v_can_procesar) = 0 THEN
         commit;
    END IF;
  END LOOP;
      -- Confirmar transacción final
    COMMIT;
END;

BEGIN
  /*Setear valores-llamar procedimiento de ta_logs de inicio de proceso*/
  IT.PRE_INI_APLICACION;
  v_fec_actual         := pag_cal.fu_obt_fec_actual(5);
  pae_cnf.g_cod_modulo := 1;
  r_log.nom_proceso    := v_nom_programa;
  r_log.fec_hor_ini    := SYSDATE;
  r_log.comentario     := '*** Inicio proceso de registro de intereses y cargos T3022D***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Deshabilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(0);

  BEGIN
    SELECT to_char(to_date(a.fec_proceso,'yyyy/mm/dd'),'dd/mm/yyyy')
      INTO v_fec_pro_arc
      FROM it.ta_cob_ajustes_cab_tmp a;
  EXCEPTION
    WHEN OTHERS THEN
      r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'al buscar la cabecera del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            SQLERRM,1,499);
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000, 'Error al buscar la cabecera del archivo. '||SQLERRM);
  END;

  BEGIN
    SELECT DISTINCT 'S'
      INTO v_exi_arc_fecha
      FROM it.ta_cob_ajustes_cab t
     WHERE t.fec_proceso = v_fec_pro_arc;
  EXCEPTION
    WHEN OTHERS THEN
      v_exi_arc_fecha := 'N';
  END;

  IF nvl(v_exi_arc_fecha, 'N')= 'S' THEN
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'El archivo T3022D ya fue conciliado'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            SQLERRM,1,499);
    r_log.men_error:='El archivo T3022D ya fue conciliado.';
    r_log.nro_error:='-20000';
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000,'El archivo T3022D ya fue conciliado. '||SQLERRM);
  END IF;

  BEGIN
    SELECT COUNT(*)
      INTO v_can_reg_tmp
      FROM ta_cob_ajustes_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      v_can_reg_tmp := 0;
  END;

  BEGIN
    SELECT c.can_registros
      INTO v_can_registros
      FROM it.ta_cob_ajustes_res_tmp c;
  EXCEPTION
    WHEN OTHERS THEN
      r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'Error al buscar el resumen del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            SQLERRM,1,499);
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000,'Error al buscar el resumen del archivo. '||SQLERRM);
  END;

  IF nvl(v_can_registros, 0) <> nvl(v_can_reg_tmp, 0) THEN
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'Cantidad de Detalle no coincide con el resumen'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            SQLERRM,1,499);
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Cantidad de Detalle no coincide con el resumen.');
  END IF;

  BEGIN
    SELECT it.s_nro_cob_ajuste.nextval
      INTO v_nro_cob_dia
      FROM dual;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al obtener el nro. de secuencia. ' || sqlerrm);
  END;

  /*Se realiza la importacion del temporal al maestro*/
  lp_val_imp_archivo(v_nro_cob_dia);
  COMMIT;
  /*Se realiza el procesamiento de los registros e insercion en ge_movimientos*/
  prt_pro_car_cie();
  COMMIT;
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de registro de intereses y cargos T3022D ***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Habilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(1);
EXCEPTION
WHEN OTHERS THEN
  r_log.comentario :=  substr('Error en proceso : ' || r_log.nom_proceso || ' - '||
                       v_lugar || ' ' ||
                       to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                       SQLERRM,1,499);
  pat_igp.pr_ins_log(r_log);
  prg_ins_log_programas(v_nom_programa,substr(SQLERRM,1,4000));
  pr_trg_activar(1);
END;
/
