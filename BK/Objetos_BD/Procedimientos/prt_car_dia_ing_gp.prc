CREATE OR REPLACE PROCEDURE IT.prt_car_dia_ing_gp IS
  v_fec_actual        ge_calendarios.fec_actual%TYPE;
  v_cod_moneda        ba_monedas.cod_moneda%TYPE;
  v_cod_usuario       ba_usuarios.cod_usuario%type:=fug_obt_pardinamico('USU_AIR_T3052');--se asigna el usuario AIRFLOW al procedimiento 
  --
  v_hora              ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_cod_tra_padre     ge_movimientos.cod_tra_padre%TYPE;
  v_hab_tra_def       varchar2(1) := nvl(fug_obt_pardinamico('IND_CON_HAB_TAB_DEF'), 'N');
  v_nro_proceso       ta_car_dia_ing_cab.nro_car_dia%type;
  v_exi_arc_fecha     varchar2(1);
  v_fec_pro_arc       ta_car_dia_ing_cab.fec_proceso%type;
  --
  r_gmovi             ge_movimientos%ROWTYPE;
  v_es_nocturno       VARCHAR2(1) := 'N';
  v_can_registros     number;
  v_can_reg_tmp       ta_car_dia_ing_res_tmp.can_registros%type;
  --
  r_log               ta_logs%ROWTYPE;
  v_error             ta_car_dia_ing_det.error%TYPE;
  v_can_reg_det       number := 0;
  v_can_procesar      number := 10;
  v_cod_ent_procesadora ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_ENT_GLOBAL');
  v_nom_programa      VARCHAR2(50) := 'PRT_CAR_DIA_ING_GP';
  v_lugar             VARCHAR2(50);

PROCEDURE lp_val_imp_archivo(p_nro_car_dia in ta_car_dia_ing_cab.nro_car_dia%type) IS
  BEGIN
    v_lugar:='Insert cabecera';    
      BEGIN
        insert into it.ta_car_dia_ing_cab
          (nro_car_dia,
           tip_registro,
           cod_ent_emisora,
           cod_marca,
           cod_ide_archivo,
           des_archivo,
           fec_proceso,
           hor_proceso,
           filler)
          (select p_nro_car_dia,
                  tc.tip_registro,
                  tc.cod_ent_emisora,
                  tc.cod_marca,
                  tc.cod_ide_archivo,
                  tc.des_archivo,
                  to_char(to_date(tc.fec_proceso, 'yyyymmdd'), 'dd/mm/yyyy'),
                  tc.hor_proceso,
                  tc.filler
             from it.ta_car_dia_ing_cab_tmp tc);
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'Error al insertar la cabecera archivo T3052D. ' || sqlerrm);
      END;
    v_lugar:='Insert resumen';
    BEGIN
      insert into it.ta_car_dia_ing_res
        (nro_car_dia,
         tip_registro,
         cod_ent_emisora,
         cod_ide_archivo,
         can_registros,
         sum_imp_mon_local,
         sum_imp_mon_ext,
         filler)
        (select p_nro_car_dia,
                tcr.tip_registro,
                tcr.cod_ent_emisora,
                tcr.cod_ide_archivo,
                tcr.can_registros,
                tcr.sum_imp_mon_local,
                tcr.sum_imp_mon_ext,
                tcr.filler
           from it.ta_car_dia_ing_res_tmp tcr);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,
                                'Error al insertar el resumen del archivo T3052D. ' ||
                                sqlerrm);
    END;
      v_lugar := 'Insert detalle';
      if nvl(v_hab_tra_def, 'N') = 'S' then
    BEGIN
      insert into it.ta_car_dia_ing_det
        (nro_car_dia,
         tip_registro,
         tip_operacion,
         cod_ent_emisora,
         suc_ent_emisora,
         cod_ent_cobradora,
         suc_ent_cobradora,
         cod_moneda,
         comprobante,
         fec_movimiento,
         nro_cuenta,
         importe,
         con_ajuste,
         deb_o_cred,
         fec_presentacion,
         fec_aplicacion,
         fec_cie_cta_cte,
         filler_1,
         filler_2,
         gru_cie_codigo,
         filler_3,
         filler_4,
         filler_5,
         procesado,
         error)
        select p_nro_car_dia,
               tip_registro,
               tip_operacion,
               cod_ent_emisora,
               suc_ent_emisora,
               cod_ent_cobradora,
               suc_ent_cobradora,
               cod_moneda,
               comprobante,
               to_char(to_date(fec_movimiento, 'yyyy/mm/dd'), 'dd/mm/yyyy') fec_movimiento,
               nro_cuenta,
               importe,
               con_ajuste,
               deb_o_cred,
               to_char(to_date(fec_presentacion, 'yyyy/mm/dd'),
                       'dd/mm/yyyy') fec_presentacion,
               decode(fec_aplicacion,
                      NULL,
                      NULL,
                      to_char(to_date(fec_aplicacion, 'yyyy/mm/dd'),
                              'dd/mm/yyyy')) fec_aplicacion,
               to_char(to_date(fec_cie_cta_cte, 'yyyy/mm/dd'), 'dd/mm/yyyy') fec_cie_cta_cte,
               filler_1,
               filler_2,
               gru_cie_codigo,
               to_number(filler_3),
               filler_4,
               filler_5,
               'N',
               decode((select distinct '1'
                        from ge_cta_clientes s
                       where s.relacion = 'P'
                         and s.nro_cuenta = i.nro_cuenta),
                      '1',
                      null,
                      'Cuenta invalida') error
          from it.ta_car_dia_ing_det_tmp i
         where to_number(i.filler_3) in
               (select ref_externa
                  from ta_tipos p
                 where p.cod_ent_procesadora = v_cod_ent_procesadora);
      commit;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,
                                'Error al insertar detalle. ' || sqlerrm);
        r_log.comentario := substr('Error al insertar detalle ' ||
                                   r_log.nom_proceso || ' - ' ||
                                   to_char(sysdate, 'dd/mm/yyyy') || ' - ' ||
                                   sqlerrm,
                                   1,
                                   499);
        pat_igp.pr_ins_log(r_log);
        prg_ins_log_programas('PRA_CAR_DIA_ING_GP',
                              substr(sqlerrm, 1, 4000));
    END;
    v_lugar:='Update detalle';   
              update it.ta_car_dia_ing_det r
              set error=error||'-No se encuentra movimiento'
              WHERE trunc(r.fec_proceso)=trunc(sysdate)
              and r.con_ajuste not in
              (select to_number(cod_referencia)
              FROM ta_ref_movimientos_gp rf
              WHERE rf.ref_archivo = 'T3052D'
              );
      END IF;
  EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20000, 'Error al insertar en las tablas definitivas. '||'Lugar: '||v_lugar||' '|| sqlerrm);
                     r_log.comentario :=substr( 'Error al insertar en las tablas definitivas. '|| r_log.nom_proceso || ' - '||
                            'Lugar: '||v_lugar||' - '||
                            to_char(sysdate, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
              pat_igp.pr_ins_log(r_log);
              prg_ins_log_programas('PRA_CAR_DIA_ING_GP',substr(sqlerrm,1,4000));
  END;
  ------------
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
  
  PROCEDURE pr_calc_montos(p_monto in number,
                           p_val_tasa in number,
                           p_imp_gravada out number,
                           p_imp_impuesto out number) is
  begin
    begin
      select trunc(round(p_monto/((100+p_val_tasa)/100)))gravada,
      trunc(round((p_val_tasa/100)*(p_monto/((100+p_val_tasa)/100))))impuesto
      into p_imp_gravada,p_imp_impuesto
      from dual;
    exception
      when others then
      p_imp_gravada:=null;
      p_imp_impuesto:=null;
    end;

  end;
  ------------
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
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CAR_DIA_ING_DET DISABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CAR_DIA_ING_DET DISABLE', v_mensaje);
    elsif p_accion=1 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CAR_DIA_ING_DET ENABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CAR_DIA_ING_DET ENABLE', v_mensaje);
    end if;
    if v_mensaje is not null then
      r_log.comentario:=v_mensaje;
      pat_igp.pr_ins_log(r_log);
    end if;
exception
  when others then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CAR_DIA_ING_DET ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CAR_DIA_ING_DET ENABLE', r_log.comentario);
      pat_igp.pr_ins_log(r_log);
end;

  -----procedimiento para ge_movimientos
procedure prt_pro_car_dia is
  v_hora              ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_fecha             ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(5);
  v_cod_ofi_matriz    ba_oficinas.cod_oficina%TYPE;
  ---------------------------------------------------
  v_mod_con_cta       ge_movimientos.cod_modulo%TYPE;
  v_descripcion       varchar2(100);
  v_mad_con_cta       ge_movimientos.cod_modalidad%TYPE;
  v_cod_oficina_cli   ge_cta_clientes.cod_oficina%type;
  v_cod_moneda        ge_cuentas.cod_moneda%type;
  v_cod_tra_padre     ge_transacciones.cod_transaccion%TYPE:='38';
  v_cod_tra_impuesto  ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto  ge_movimientos.cod_tasa%type;
  v_cod_tra_gravada   ge_movimientos.cod_transaccion%TYPE;
  v_importe_gravada   ta_car_dia_ing_det.importe%type;
  v_importe_impuesto   ta_car_dia_ing_det.importe%type;
  ---------------------------------------------------
  v_es_nocturno       VARCHAR2(1) := 'N';
  r_gmovi             ge_movimientos%ROWTYPE;
  v_error             varchar2(500);
  --------------------------------
  v_val_tas_cargo     ge_movimientos.val_tasa%type;
  v_cod_usu_proceso   ba_usuarios.cod_usuario%type;
  v_ind_usuario       number;
CURSOR movs IS
select nro_cuenta,con_ajuste,importe,comprobante,
fec_presentacion,rowid id_fila
from it.ta_car_dia_ing_det a
where a.error is null
and nvl(a.procesado,'N')='N'
--filler_3 equivalente a cod_producto
and a.filler_3 in (select ref_externa from ta_tipos p
                 where p.cod_ent_procesadora= v_cod_ent_procesadora)
and a.fec_proceso>= a.fec_proceso-30;

BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
  Begin
      Select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
  exception
    when others then
      v_cod_ofi_matriz := 1;
  end;
  FOR c IN movs LOOP
    v_error:=null;
    v_descripcion:=null;
    v_importe_gravada:=null;
    v_importe_impuesto:=null;
    v_cod_tra_impuesto:=null;
    v_cod_tas_impuesto:=null;
    v_val_tas_cargo:=null;
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
         v_error := (' Error al obtener la cuenta '|| c.nro_cuenta);
      END;

      --***Obs. importantes
      --***El codigo de la gravada de la transaccion sera almacenado
      --en la columna cod_transaccion de la tabla ta_ref_movimientos_gp
      --***El codigo de transaccion referente al IVA se recupera de la tabla ge_transacciones_det

        begin
              SELECT r.cod_transaccion,r.descripcion
              INTO v_cod_tra_gravada,v_descripcion
              FROM ta_ref_movimientos_gp r
              WHERE r.cod_referencia = c.con_ajuste
              and r.cod_modalidad = v_mad_con_cta
              and r.procesa='S'
              and  r.ref_archivo like 'T3052D';
              exception
                when no_data_found then
                  v_cod_tra_gravada:=null;
                when others then
                  v_cod_tra_gravada:=null;
         end;
      if v_cod_tra_gravada is not null then
       begin
         SELECT a.cod_transaccion,a.cod_tasa,c.val_tasa
         into v_cod_tra_impuesto,v_cod_tas_impuesto, v_val_tas_cargo
          FROM ge_transacciones a, ge_tasas b, ge_tas_fechas c
          WHERE a.cod_tasa = b.cod_tasa
             AND b.cod_tasa = c.cod_tasa
             AND c.cod_moneda = v_cod_moneda
             AND a.cod_transaccion =(
                SELECT cod_tra_hijo
                FROM ge_transacciones_det
                WHERE cod_modulo = v_mod_con_cta
                AND cod_modalidad = v_mad_con_cta
                AND cod_transaccion = v_cod_tra_gravada
             )
             AND a.cod_modalidad = v_mad_con_cta
             AND c.fec_vigencia = (SELECT MAX(x.fec_vigencia)
                                     FROM ge_tas_fechas x
                                    WHERE x.cod_tasa = c.cod_tasa
                                      AND x.cod_moneda = v_cod_moneda);
                 pr_calc_montos(c.importe,v_val_tas_cargo,v_importe_gravada,v_importe_impuesto);
         exception
                when no_data_found then
                  v_cod_tra_impuesto:=null;
                  v_importe_gravada :=c.importe;
                  v_importe_impuesto:=null;
                when others then
                  v_cod_tra_impuesto:=null;
                  v_importe_gravada :=null;
                  v_importe_impuesto:=null;
          end;
          
        end if;


      IF v_mod_con_cta IS NOT NULL and v_cod_tra_gravada is not null THEN
       BEGIN
        r_gmovi := NULL;
       ----------------------------------------------------------------------------------------------------------
        v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
        v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
        v_hora              := fu_obt_hora(v_ind_usuario);
        pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
       ----------------------------------------------------------------------------------------------------------
        --IMPORTE
        r_gmovi.cod_modulo      := v_mod_con_cta;
        r_gmovi.cod_modalidad   := v_mad_con_cta;
        r_gmovi.cod_oficina     := v_cod_oficina_cli;
        r_gmovi.nro_cuenta      := c.nro_cuenta;
        r_gmovi.nro_documento   :=to_number(c.comprobante);
        r_gmovi.cod_rubro       := '';
        r_gmovi.tip_mov_rubro   := '';
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_usuario     := v_cod_usu_proceso;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.nro_secuencia   := '1';
        r_gmovi.fec_valor       := c.fec_presentacion;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_mod_con_cta;
        r_gmovi.cod_mad_padre   := v_mad_con_cta;
        r_gmovi.cod_transaccion := v_cod_tra_gravada;
        BEGIN
        r_gmovi.cod_persona     := it.fug_obt_cli_principal(c.nro_cuenta);
        EXCEPTION
           when others then
             r_gmovi.cod_persona     :=null;
        END;
        r_gmovi.monto           := trunc(v_importe_gravada);
        r_gmovi.cod_tasa        := NULL;
        r_gmovi.val_tasa        := NULL;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := v_cod_ofi_matriz;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := v_descripcion;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';

        IF trunc(r_gmovi.monto)>0 THEN
          pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
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
                      v_error:=substr(('Error en el importe gravado.: ' || SQLERRM || ' ' || c.nro_cuenta),1,499);
                       end;
                    end;
                  end;
                end;
              end;
           end;
        END;
        r_gmovi := NULL;
        --IMPORTE IVA

        IF v_cod_tra_impuesto IS NOT NULL and v_error is null THEN--si encontro que tiene transaccion de IVA cargado ingresa

            BEGIN
              r_gmovi.cod_modulo      := v_mod_con_cta;
              r_gmovi.cod_modalidad   := v_mad_con_cta;
              r_gmovi.cod_oficina     := v_cod_oficina_cli;
              r_gmovi.nro_cuenta      := c.nro_cuenta;
              r_gmovi.cod_rubro       := '';
              r_gmovi.tip_mov_rubro   := '';
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.nro_documento   := to_number(c.comprobante);
              r_gmovi.cod_usuario     := v_cod_usu_proceso;
              r_gmovi.hora            := v_hora;
              r_gmovi.fecha           := v_fecha;
              r_gmovi.nro_secuencia   := '2';
              r_gmovi.fec_valor       := c.fec_presentacion;
              r_gmovi.cod_tra_padre   := v_cod_tra_padre;
              r_gmovi.cod_mod_padre   := v_mod_con_cta;
              r_gmovi.cod_mad_padre   := v_mad_con_cta;
              r_gmovi.cod_transaccion := v_cod_tra_impuesto;
              BEGIN
              r_gmovi.cod_persona     := it.fug_obt_cli_principal(c.nro_cuenta);
              EXCEPTION
                 when others then
                   r_gmovi.cod_persona     :=null;
              END;
              r_gmovi.monto           := trunc(v_importe_impuesto);
              r_gmovi.cod_tasa        := v_cod_tas_impuesto;
              r_gmovi.val_tasa        := v_val_tas_cargo;
              r_gmovi.cotizacion      := NULL;
              r_gmovi.cod_ofi_origen  := v_cod_ofi_matriz;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := v_descripcion;
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';

              IF trunc(r_gmovi.monto)>0 THEN
                 pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
              END IF;
              EXCEPTION
                WHEN OTHERS THEN
                  v_error := v_error||'.Error en Iva: ' || SQLERRM || ' '  ||c.nro_cuenta;
              END;
        END IF;--termina IVA

        IF v_error IS NOT NULL THEN
            r_log.fec_hor_ini := SYSDATE;
            r_log.nom_proceso := v_nom_programa;
            r_log.comentario  := substr(v_error,1,499);
            pat_igp.pr_ins_log(r_log);
            begin
              update ta_car_dia_ing_det s
                 set error = substr(v_error, 1, 499)
               where rowid = c.id_fila;
            end;
        ELSE
          begin
            update ta_car_dia_ing_det s
               set s.procesado = 'S'
             where rowid = c.id_fila;
          end;
        END IF;
    ELSE
      --No se encontro mod. cta o gravada
      BEGIN
        update ta_car_dia_ing_det s
           set error = substr(v_error, 1, 499)
         where rowid = c.id_fila;
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
  --inicio
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_fec_actual := pag_cal.fu_obt_fec_actual(5);

  r_log.nom_proceso := v_nom_programa;
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Inicio proceso de archivo T3052D - Cargos Diarias***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Deshabilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(0);

  begin
    select to_char(to_date(a.fec_proceso,'yyyy/mm/dd'),'dd/mm/yyyy')--fec_proceso
      into v_fec_pro_arc
      from it.ta_car_dia_ing_cab_tmp a;
  exception
    when others THEN
      r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'al buscar la cabecera del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000, 'Error al buscar la cabecera del archivo. '||sqlerrm);
  end;

  begin
    select distinct 'S'
      into v_exi_arc_fecha
      from it.ta_car_dia_ing_cab t
     where t.fec_proceso = v_fec_pro_arc;
  exception
    when others then
      v_exi_arc_fecha := 'N';
  end;

  if nvl(v_exi_arc_fecha, 'N')= 'S' THEN
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'El archivo T3052D ya fue conciliado'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
    r_log.men_error:='El archivo T3052D ya fue conciliado.';
    r_log.nro_error:='-20000';
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000,'El archivo T3052D ya fue conciliado. '||sqlerrm);
  end if;

  begin
    select count(*)
      into v_can_reg_tmp
      from ta_car_dia_ing_det_tmp;
  exception
    when others then
      v_can_reg_tmp := 0;
  end;

  begin
    select c.can_registros
      into v_can_registros
      from ta_car_dia_ing_res_tmp c;
  exception
    when others THEN
      r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'Error al buscar el resumen del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000,'Error al buscar el resumen del archivo. '||sqlerrm);
  end;

  if nvl(v_can_registros, 0) <> nvl(v_can_reg_tmp, 0) THEN
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'Cantidad de Detalle no coincide con el resumen'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Cantidad de Detalle no coincide con el resumen.');
  end if;

  BEGIN
    select it.s_nro_car_dia_gp.nextval
      into v_nro_proceso
      from dual;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al obtener el nro. de secuencia. ' || sqlerrm);
  END;

  --se importa el archivo
  lp_val_imp_archivo(v_nro_proceso);
  commit;
  --procedure
  prt_pro_car_dia();
  commit;
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de archivo T3052D - Cargos Diaras ***';
  pat_igp.pr_ins_log(r_log, FALSE);
  --Habilitar TRIGGERS DE AUDITORIA --
  pr_trg_activar(1);

EXCEPTION
  WHEN OTHERS THEN
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
    pat_igp.pr_ins_log(r_log);
    prg_ins_log_programas(v_nom_programa,substr(sqlerrm,1,4000));
    pr_trg_activar(1);
END;
/
