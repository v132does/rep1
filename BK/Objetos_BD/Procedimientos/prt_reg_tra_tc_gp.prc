create or replace procedure it.prt_reg_tra_tc_gp IS
  ----------------
  cursor c_mov_gp (p_ica_ente number,
                   p_cod_ent_procesadora number) is
   select a.nro_con_dia,
          a.tip_registro,
          DECODE(a.cod_ica_adquiriente,
                 p_ica_ente,
                 DECODE(a.cod_tip_transaccion,
                        0,
                        9,
                        2,
                        10,
                        a.cod_tip_transaccion),
                 a.cod_tip_transaccion) cod_tip_transaccion,
          a.cta_externa nro_cuenta,
          a.cod_autorizacion,
          a.nro_tarjeta,
          a.nro_comprobante,
          a.imp_mon_original,
          a.imp_mon_movimiento,
          a.cod_comercio,
          a.nom_comercio,
          a.fec_operacion,
          a.hor_operacion,
          SUBSTR(a.des_movimiento || ' ' || upper(a.nom_comercio), 1, 100) concepto,
          rowid id_fila
     from ah_con_dia_det a
    where a.error is null
      and nvl(a.procesado, 'N') = 'N'
      and a.tip_producto in
          (select distinct p.ref_externa
             from ta_tipos p
            where p.cod_ent_procesadora = p_cod_ent_procesadora)
      and trunc(a.imp_mon_movimiento) > 0
      and a.cod_tip_transaccion in
          (select cod_referencia
             from ta_ref_movimientos_gp a
            where procesa like 'S'
              and a.ref_archivo = 'T2001D')
      and a.fec_proceso >= a.fec_proceso - 30;
  ---------------
  v_cod_usuario     ba_usuarios.cod_usuario%type:=fug_obt_pardinamico('USU_AIR_T2001');--se asigna el usuario AIRFLOW al procedimiento
  v_fecha           ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(5);
  v_fec_valor       ge_movimientos.fec_valor%TYPE := trunc(sysdate);
  v_hora            ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,
                                                             'HH24:MI:SS');
  ---------------------------------------------------
  v_mod_con_cta     ge_movimientos.cod_modulo%TYPE;
  v_mad_con_cta     ge_movimientos.cod_modalidad%TYPE;
  v_cod_oficina_cli ge_cta_clientes.cod_oficina%type;
  v_cod_moneda      ge_cuentas.cod_moneda%type;
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
  ---------------------------------------------------
  v_es_nocturno     VARCHAR2(1) := 'N';
  r_gmovi           ge_movimientos%ROWTYPE;
  v_lugar           varchar2(50);
  v_nom_programa    varchar2(50) := 'IT.PRT_REG_TRA_TC_GP';
  r_log             ta_logs_gp%ROWTYPE;
  v_error           varchar2(4000);
  v_cod_usu_proceso ba_usuarios.cod_usuario%type;
  v_ind_usuario     number;
  v_cod_tra_padre   ge_transacciones.cod_transaccion%type;
  --v_cod_tra_ade     ge_transacciones.cod_transaccion%type := '1859';--TRANSACCION CREDITO ADE
  --v_cta_ficticia    ge_cuentas.nro_cuenta%type := fug_obt_pardinamico('TAR_NRO_CTA_FICTICIA');
  --v_cod_mod_ade     ge_movimientos.cod_modulo%TYPE;
  --v_cod_mad_ade     ge_movimientos.cod_modalidad%TYPE;
  v_ica_adelanto    number := fug_obt_pardinamico('TAR_VAL_ICA_ADELANTO');
  v_cod_ent_procesadora number := fug_obt_pardinamico('COD_ENT_GLOBAL');
  --------------------------------
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
                         p_fecha out date ) IS
    v_es_nocturno    VARCHAR2(1) := 'N';
    v_fec_proceso    ge_movimientos.fecha%TYPE;
    v_est_modulo     ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(5);
    v_hor_limite     varchar2(8) := '999999';
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
BEGIN--EMPIEZA
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  r_log.nom_proceso:=v_nom_programa;

  FOR c IN c_mov_gp(v_ica_adelanto,v_cod_ent_procesadora) LOOP
    r_gmovi := null;
    v_error:=null;
    r_log.comentario:=null;
    ----------------------------------------------------------------------------------------------------------
    v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
    v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
    v_hora              := fu_obt_hora(v_ind_usuario);
    pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
    ----------------------------------------------------------------------------------------------------------
    v_lugar := '01';
    --se recuperan datos para el movimiento del cliente
    begin
      select s.cod_modulo,s.cod_modalidad,s.cod_oficina,s.cod_moneda
      into v_mod_con_cta,v_mad_con_cta,v_cod_oficina_cli,v_cod_moneda
      from ge_cuentas s
     where s.nro_cuenta = c.nro_cuenta;
    exception
      when no_data_found then
        v_error:='No se encontro modalidad';
        v_mod_con_cta:=null;
        v_mad_con_cta:=null;
        v_cod_oficina_cli:=null;
        v_cod_moneda:=null;
      when others then
         v_error:='Error al recuperar modalidad';
         r_log.comentario := substr('Error al recuperar modalidad de la cuenta nro :'||c.nro_cuenta||' - ' || r_log.nom_proceso || ' - '||
                            to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
          pat_igp.pr_ins_log(r_log);
    end;
    v_lugar := '02';
      begin
       select s.cod_transaccion
       into v_cod_transaccion
       from ge_transacciones s,ta_ref_movimientos_gp a
       where s.cod_transaccion=a.cod_transaccion
       and s.cod_modalidad=a.cod_modalidad
       and s.cod_modalidad=v_mad_con_cta
       and a.procesa='S'
       and a.cod_referencia=c.cod_tip_transaccion
       and a.ref_archivo='T2001D';
      exception
        when others then
          v_error:=v_error||'.No se encontro cod_transaccion para '||c.cod_tip_transaccion;
          v_cod_transaccion:=null;
          r_log.comentario := substr('Error al recuperar transaccion p/ la cuenta nro :'||c.nro_cuenta||' - '|| r_log.nom_proceso || ' - '||
                            to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
          pat_igp.pr_ins_log(r_log);
      end;
      
      IF c.cod_tip_transaccion in (9,10) then
          v_cod_tra_padre := '1857';--ADE
      ELSE 
          v_cod_tra_padre := '38';
      END IF;
      
    IF v_mod_con_cta is not null and v_cod_transaccion is not null and v_error is null THEN
      r_gmovi.cod_modulo      := v_mod_con_cta;
      r_gmovi.cod_modalidad   := v_mad_con_cta;
      r_gmovi.cod_oficina     := v_cod_oficina_cli;
      r_gmovi.nro_cuenta      := c.nro_cuenta;
      r_gmovi.cod_rubro       := '';
      r_gmovi.tip_mov_rubro   := '';
      r_gmovi.cod_moneda      := v_cod_moneda;
      r_gmovi.cod_usuario     := v_cod_usu_proceso;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.nro_secuencia   := '1';
      r_gmovi.fec_valor       := v_fec_valor;
      r_gmovi.cod_tra_padre   := v_cod_tra_padre;
      r_gmovi.cod_mod_padre   := v_mod_con_cta;
      r_gmovi.cod_mad_padre   := v_mad_con_cta;
      r_gmovi.cod_transaccion := v_cod_transaccion;
      r_gmovi.nro_documento   := c.nro_comprobante;
      begin
      r_gmovi.cod_persona     :=it.fug_obt_cli_principal(c.nro_cuenta);
       exception
          when others then
            r_gmovi.cod_persona     :=null;
        end;
      ------------------
      r_gmovi.monto          := trunc(c.imp_mon_movimiento);
      r_gmovi.cod_tasa       := NULL;
      r_gmovi.val_tasa       := NULL;
      r_gmovi.cotizacion     := NULL;
      r_gmovi.cod_ofi_origen := v_cod_oficina_cli;
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.concepto       := c.concepto;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      BEGIN
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      EXCEPTION
        WHEN others THEN
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
                        v_error:=v_error||'.Error al ins: ' || SQLERRM ||' '||c.nro_cuenta;
                      end;
                    end;
                  end;
                end;
             end;
          end;
      END;
    /*v_lugar := '03';
    r_gmovi := NULL;              
      if v_error is null and c.cod_tip_transaccion in (9,10) then
          BEGIN
            SELECT cod_modulo, cod_modalidad
              INTO v_cod_mod_ade,
                   v_cod_mad_ade
              FROM cc_cta_ficticias
             WHERE nro_cuenta = v_cta_ficticia;
          EXCEPTION
            WHEN no_data_found THEN
              v_cod_mod_ade := null;
              v_cod_mad_ade := null;
          END;  
      
      r_gmovi.cod_modulo      := v_cod_mod_ade;
      r_gmovi.cod_modalidad   := v_cod_mad_ade;
      r_gmovi.cod_oficina     := v_cod_oficina_cli;
      r_gmovi.nro_cuenta      := v_cta_ficticia;--cta_ficticia
      r_gmovi.cod_rubro       := '';
      r_gmovi.tip_mov_rubro   := '';
      r_gmovi.cod_moneda      := v_cod_moneda;
      r_gmovi.cod_usuario     := v_cod_usu_proceso;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.nro_secuencia   := '2';
      r_gmovi.fec_valor       := v_fec_valor;
      r_gmovi.cod_tra_padre   := v_cod_tra_padre;  
      r_gmovi.cod_mod_padre   := v_mod_con_cta;
      r_gmovi.cod_mad_padre   := v_mad_con_cta;
      r_gmovi.cod_transaccion := v_cod_tra_ade;
      r_gmovi.nro_documento   := c.nro_comprobante;
       begin
      r_gmovi.cod_persona     := it.fug_obt_cli_principal(c.nro_cuenta);
       exception
          when others then
            r_gmovi.cod_persona := null;
        end;
      ------------------
      r_gmovi.monto           := trunc(c.imp_mon_movimiento);
      r_gmovi.cod_tasa        := NULL;
      r_gmovi.val_tasa        := NULL;
      r_gmovi.cotizacion      := NULL;
      r_gmovi.cod_ofi_origen  := v_cod_oficina_cli;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := c.concepto;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      BEGIN
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      EXCEPTION
          WHEN OTHERS THEN
                 v_error:=substr(('.Error en Secuencia 2 ADE: ' || SQLERRM || ' ' ||c.nro_cuenta),1,499);
      END;
      end if;*/--se comenta temporalente para actualización criterios
      if v_error is null then
        begin
        update ah_con_dia_det a
           set a.procesado = 'S'
         where rowid = c.id_fila;
          if sql%notfound then
           r_log.comentario := substr('Error al encontrar registro p/ actualizar la cuenta nro :'||c.nro_cuenta||' - '|| r_log.nom_proceso || ' - '||
           to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
           sqlerrm,1,499);
           pat_igp.pr_ins_log(r_log);
          end if;
        exception
          when others then
           r_log.comentario := substr('Error al actualizar la cuenta nro :'||c.nro_cuenta||' - '|| r_log.nom_proceso || ' - '||
           to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
           sqlerrm,1,499);
           pat_igp.pr_ins_log(r_log);
        end;
      else
        r_log.fec_hor_ini := SYSDATE;
        r_log.comentario  := substr(v_error,1,499);
        pat_igp.pr_ins_log(r_log);
        begin
        update ah_con_dia_det a
           set a.error = SUBSTR(v_error, 1, 499)
         where rowid = c.id_fila;
        exception
           when others then
            r_log.comentario := substr('Error al actualizar la cuenta :'||c.nro_cuenta||' - '|| r_log.nom_proceso || ' - '||
             to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
             sqlerrm,1,499);
             pat_igp.pr_ins_log(r_log);
        end;
       end if;
    END IF;
     commit;
  end loop;
exception
  when others then
   r_log.comentario := substr('Error en proceso de transacciones: ' || ' - '||
                            sysdate || ' - ' ||
                            sqlerrm,1,499);
    pat_igp.pr_ins_log(r_log);
    prg_ins_log_programas(v_nom_programa,substr(sqlerrm,1,4000));
end;
/
