create or replace procedure it.prt_pro_dev_con_gp IS
  -----------------------
  cursor c_mov_dev_gp is
    select tip_registro,nro_con_dia,cod_autorizacion,
           a.cta_externa nro_cuenta,
           a.nro_cuenta nro_cuenta_gp,
           a.nro_tarjeta,
           a.imp_mon_original,
           a.imp_mon_movimiento,
           a.imp_tot_movimiento,
           a.cod_comercio,
           a.nom_comercio,
           a.fec_operacion,
           a.hor_operacion,
           SUBSTR(des_movimiento || ' ' || upper(nom_comercio),1,100) concepto,
           a.nro_comprobante,
           b.cod_modulo,
           b.cod_modalidad,
           b.cod_oficina,
           b.cod_moneda,
           b.estado,
           a.rowid id_fila
      from ah_con_dia_det a, ge_cuentas b
     where a.cod_movimiento like '801'
     and a.tip_producto = '20'
     and to_number(a.estado) <> 0
     and nvl(a.procesado,'N') = 'N'
     and error is null
     and a.fec_proceso >= a.fec_proceso-30
     and a.cta_externa = b.nro_cuenta;
  -----------------------
  v_cod_usuario         ba_usuarios.cod_usuario%type:=fug_obt_pardinamico('USU_AIR_T2001');--se asigna el usuario AIRFLOW al procedimiento
  v_fecha               ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(5);
  v_hora                ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,
                                                             'HH24:MI:SS');
  v_cod_rub_deb         ge_movimientos.cod_rubro%TYPE;
  v_mod_con_deb         ge_movimientos.cod_modulo%TYPE;
  v_mad_con_deb         ge_movimientos.cod_modalidad%TYPE;
  v_nro_cta_fic         ge_movimientos.nro_cuenta%TYPE;
  v_es_nocturno         VARCHAR2(1) := 'N';
  v_cod_ofi_matriz      ge_cta_clientes.cod_oficina%type;
  r_gmovi               ge_movimientos%ROWTYPE;
  v_lugar               varchar2(50);
  v_nom_programa        varchar2(50) := 'IT.PRT_PRO_DEV_CON_GP';
  r_log                 ta_logs_gp%ROWTYPE;
  v_error               varchar2(4000);
  v_rub_ope_can_gs      cb_rubros.cod_rubro%type := fug_obt_pardinamico('COD_RUB_OPE_CAN', null, null, pag_gen.fu_obt_mon_local);
  v_rub_ope_can_usd     cb_rubros.cod_rubro%type := fug_obt_pardinamico('COD_RUB_OPE_CAN', null, null, pag_gen.fu_obt_mon_fuerte);
  v_mon_local           ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_mon_extranjera      ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  v_cot_debito          ge_movimientos.cotizacion%type;
  v_cot_credito         ge_movimientos.cotizacion%type;
  v_imp_conversion      ge_movimientos.monto%type;
  v_cod_usu_proceso     ba_usuarios.cod_usuario%type;
  v_ind_usuario         number;

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
BEGIN--EMPIEZA
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  FOR c IN c_mov_dev_gp LOOP
    v_error := null;
    v_nro_cta_fic := fug_obt_pardinamico('GEN_NRO_CTA_FIC',null,null,'GS');
    ----------------------------------------------------------------------------------------------------------
    v_cod_usu_proceso   := it.fug_obt_mov_user(v_cod_usuario,'S_SER_USER_'||v_cod_usuario);
    v_ind_usuario       := to_number(NVL(replace(replace(v_cod_usu_proceso,v_cod_usuario,null),'_',null),0));
    v_hora              := fu_obt_hora(v_ind_usuario);
    pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
    ----------------------------------------------------------------------------------------------------------
    v_imp_conversion := c.imp_mon_movimiento;
    v_lugar := '01';
    BEGIN                   
     IF v_mon_local <> c.cod_moneda then  --aqui debo evaluar si la moneda de la cuenta es diferente a la trx
        v_imp_conversion := null;
        paj_glo.lp_con_mon_a_moneda(c.cod_moneda, --cod_moneda cuenta
                                    v_mon_local,  --cod_moneda trx
                                    v_imp_conversion, --devuelve el valor convertido.
                                    c.imp_mon_movimiento, --monto trx
                                    v_cot_debito,
                                    v_cot_credito);
     END IF;
                           
      --se recuperan datos para el movimiento del rubro relacionado
      SELECT cod_rubro, cod_modulo, cod_modalidad
        INTO v_cod_rub_deb, v_mod_con_deb, v_mad_con_deb
        FROM cc_cta_ficticias
       WHERE nro_cuenta = v_nro_cta_fic;
    EXCEPTION
      WHEN others THEN
        v_error := 'No se encontro rubro.';
        v_cod_rub_deb := null;
        v_mod_con_deb := null;
        v_mad_con_deb := null;
        prg_ins_log_programas(v_nom_programa,
                              substr('Lugar: ' || v_lugar ||
                                     '.Error al recuperar rubro,modulo,modalidad. - ' ||
                                     sqlerrm,
                                     1,
                                     4000),
                              '',
                              c.nro_cuenta);
       r_log.comentario := substr('Lugar: ' || v_lugar ||
                                     '.Error al recuperar rubro,modulo,modalidad. - Cuenta: ' ||c.nro_cuenta||
                                     sqlerrm,1,499);
       pat_igp.pr_ins_log(r_log);
    END;
    Begin
      Select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
    exception
      when others then
        v_cod_ofi_matriz := 1;
    end;
    v_lugar := '02';
    IF v_cod_rub_deb is not null and v_error is null then   
      --Construyo el movimiento dependiendo del estado de la cuenta
        r_gmovi.cod_modulo      := c.cod_modulo;
        r_gmovi.cod_modalidad   := c.cod_modalidad;
        r_gmovi.cod_oficina     := c.cod_oficina;
        
        r_gmovi.nro_documento   := c.nro_comprobante;
        if c.estado = 'C' then
          r_gmovi.nro_cuenta    := '';
          if c.cod_moneda = v_mon_local then
          r_gmovi.cod_rubro     := v_rub_ope_can_gs;
          elsif c.cod_moneda = v_mon_extranjera then
              r_gmovi.cod_rubro := v_rub_ope_can_usd;
          else
            r_gmovi.cod_rubro   := v_rub_ope_can_gs;
          end if;
          r_gmovi.tip_mov_rubro := 'D';
          r_gmovi.referencia    := c.nro_cuenta;   
        else
          r_gmovi.nro_cuenta    := c.nro_cuenta;
          r_gmovi.cod_rubro     := '';
          r_gmovi.tip_mov_rubro := '';
          r_gmovi.referencia    := ''; 
        end if;
        begin
          r_gmovi.cod_persona   := it.fug_obt_cli_principal(c.nro_cuenta);
        exception
          when others then
            r_gmovi.cod_persona := null;
        end;
        r_gmovi.cod_moneda      := c.cod_moneda;
        r_gmovi.cod_usuario     := v_cod_usu_proceso;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.nro_secuencia   := '1';
        r_gmovi.fec_valor       := trunc(c.fec_operacion);
        r_gmovi.cod_tra_padre   := '380';
        r_gmovi.cod_mod_padre   := '9';
        r_gmovi.cod_mad_padre   := '91';
        r_gmovi.cod_transaccion := '503';
        r_gmovi.monto           := v_imp_conversion * (-1);----c.imp_mon_movimiento * (-1);
        r_gmovi.cod_tasa        := NULL;
        r_gmovi.val_tasa        := NULL;
        r_gmovi.cotizacion      := NULL;
        r_gmovi.cod_ofi_origen  := c.cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := c.concepto;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
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
      IF v_error IS NULL THEN
        -------------------------------------------------------
        --HACEMOS CREDITO CON MONTO NEGATIVO(DEBITO) AL RUBRO CORRESPONDIENTE.
        r_gmovi.cod_modulo    := v_mod_con_deb;
        r_gmovi.cod_modalidad := v_mad_con_deb;
        r_gmovi.cod_oficina   := v_cod_ofi_matriz;
        r_gmovi.nro_cuenta    := '';
        r_gmovi.cod_rubro     := v_cod_rub_deb;
        r_gmovi.tip_mov_rubro := 'C';
        --
        r_gmovi.cod_moneda    := v_mon_local;--solo local porque la cuenta recaudadora es en Gs
        r_gmovi.cod_usuario   := v_cod_usu_proceso;
        r_gmovi.hora          := v_hora;
        r_gmovi.fecha         := v_fecha;
        r_gmovi.nro_secuencia := '2';
        --
        r_gmovi.nro_documento   := c.nro_comprobante;
        r_gmovi.referencia      := ' ';
        r_gmovi.fec_valor       := trunc(c.fec_operacion);
        r_gmovi.cod_tra_padre   := '380';
        r_gmovi.cod_mod_padre   := '9';
        r_gmovi.cod_mad_padre   := '91';
        r_gmovi.cod_transaccion := '101';
        r_gmovi.monto           := c.imp_mon_movimiento * (-1);
        --
        r_gmovi.cod_tasa    := NULL;
        r_gmovi.val_tasa    := NULL;
        r_gmovi.cotizacion  := NULL;
        r_gmovi.emi_aviso   := 'N';
        r_gmovi.concepto    := c.concepto;
        r_gmovi.estado      := 'N';
        r_gmovi.reversado   := 'N';
        begin
        pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        exception
          when others then
                 v_error:=v_error||'.Error al ins rub: ' || SQLERRM ||' '||c.nro_cuenta;
        END;
      END IF;
    END IF;
    v_lugar := '03';

    IF v_error IS NULL and c.estado <> 'C' THEN
    --updatear cuenta del cliente siempre que no este cancelada
      BEGIN
        it.PAJ_GLO.pr_upd_cta_credito('N',
                                      v_es_nocturno,
                                      c.cod_modulo,
                                      c.cod_modalidad,
                                      c.nro_cuenta,
                                      v_fecha,
                                      v_hora,
                                      v_imp_conversion);
      EXCEPTION
        WHEN OTHERS THEN

          v_error:=v_error||'.Error al act. Cta.: ' || SQLERRM ||' '||c.nro_cuenta;
          r_log.fec_hor_ini := sysdate;
          r_log.comentario  := substr(v_error,1,499);
          pat_igp.pr_ins_log(r_log);
      END;
    END IF;

      IF SQLCODE=0 AND v_error IS NULL THEN
        begin
        update ah_con_dia_det a
           set a.procesado ='S'
         where  rowid = c.id_fila;
          if sql%notfound then
           v_error:=substr(v_error||'Error al actualizar procesado',1,499);
           r_log.nom_proceso:=v_nom_programa;
           r_log.comentario := substr('Error al encontrar registro p/ actualizar la cuenta nro :'||c.nro_cuenta||' - '|| r_log.nom_proceso || ' - '||
           to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
           sqlerrm,1,499);
           pat_igp.pr_ins_log(r_log);
          end if;
        exception
          when others then
           r_log.nom_proceso:=v_nom_programa;
           r_log.comentario := substr('Error al actualizar la cuenta nro :'||c.nro_cuenta||' - '|| r_log.nom_proceso || ' - '||
           to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
           sqlerrm,1,499);
           pat_igp.pr_ins_log(r_log);
        end;
      else
          r_log.fec_hor_ini:= sysdate;
          r_log.comentario :=  substr(v_error,1,499);
          pat_igp.pr_ins_log(r_log);
        begin
        update ah_con_dia_det a
           set a.error ='Error al realizar devolucion cuenta nro. '||c.nro_cuenta ||'Verificar ta_logs_gp.'
        where rowid = c.id_fila;
        exception
          when others then
           r_log.nom_proceso:=v_nom_programa;
           r_log.comentario := substr('Error al actualizar la cuenta :'||c.nro_cuenta||' - '|| r_log.nom_proceso || ' - '||
           to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
           sqlerrm,1,499);
           pat_igp.pr_ins_log(r_log);
        end;
      end if;
      commit;
  end loop;
end;
/
