CREATE OR REPLACE PACKAGE BODY IT.PAG_SUE IS
    p_fec_hoy date;
    v_form CHAR(1) := 'S'; --- indica si es esjecutado en el cierre S/N ;
    p_cierre varchar2(1);

    FUNCTION fu_obt_ubicacion RETURN VARCHAR2 IS
      v_linea    VARCHAR2(1000);
      v_paquete  VARCHAR2(1000);
      v_llamador VARCHAR2(1000);
      v_duenho   VARCHAR2(1000);
    BEGIN
      OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
      RETURN v_paquete || '.' || v_linea ;
    END;

    PROCEDURE LP_ACT_GE_PAG_SUELDOS
    (P_COD_ENTE IN NUMBER, P_FEC_PROCESO IN DATE, P_NRO_SECUENCIA IN NUMBER,
     P_NRO_CUENTA IN VARCHAR2, P_COD_PROCESO IN NUMBER) IS

        PROCEDURE LP_ACT_TABLA_PRAGMA IS
            PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
        BEGIN
            UPDATE ge_pag_sueldos
            set cod_proceso = p_cod_proceso
            where cod_ente = P_COD_ENTE
              and fec_proceso = p_fec_proceso
              and nro_secuencia = p_nro_secuencia
              and nro_cuenta = p_nro_cuenta;
            COMMIT;
        END;

    BEGIN
        IF v_form != 'N' THEN
            LP_ACT_TABLA_PRAGMA;
        ELSE

            UPDATE ge_pag_sueldos
            set cod_proceso = p_cod_proceso
            where cod_ente = P_COD_ENTE
              and fec_proceso = p_fec_proceso
              and nro_secuencia = p_nro_secuencia
              and nro_cuenta = p_nro_cuenta;
        END IF;
    END;

    PROCEDURE LP_ACT_GE_PAG_SUELDOS
    (P_FILA IN VARCHAR2, P_COD_PROCESO IN NUMBER) IS

        PROCEDURE LP_ACT_TABLA_PRAGMA IS
            PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
        BEGIN
            UPDATE ge_pag_sueldos
            set cod_proceso = p_cod_proceso
            where rowid = p_fila;
            COMMIT;
        END;

    BEGIN
        IF v_form != 'N' THEN
            LP_ACT_TABLA_PRAGMA;
        ELSE
            UPDATE ge_pag_sueldos
            set cod_proceso = p_cod_proceso
            where rowid = p_fila;
        END IF;
    END;

/* Inserta en el GE_PAG_SUELDOS_TMP los registros con error */
    PROCEDURE LP_INS_ERROR_PROCESO
    (P_COD_ENTE IN NUMBER
    ,P_FEC_HOY IN DATE
    ,P_LUGAR IN OUT VARCHAR2
    ,P_NRO_SECUENCIA IN NUMBER
    ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
    ,P_FEC_INSERCION IN GE_PAG_SUELDOS.FEC_INSERCION%TYPE DEFAULT NULL
    );
/* Verifica si no existe algo a reprocesar o sin procesar */
    PROCEDURE PR_VER_PAG_SUELDO
    (P_DATOS IN OUT VARCHAR2
    ,P_REPROCESA IN OUT VARCHAR2
    ,P_FECHA IN OUT DATE
    ,P_COD_ENTE IN NUMBER
    ,P_LUGAR IN OUT VARCHAR2
    )
        IS

        v_ente    GE_PAG_SUELDOS_TMP.cod_ente%type;
        v_fec_actual date;
    begin
        p_lugar := 'VERIFICA DATOS EN GE_PAG_SUELDOS ';
        -- Se busca si existe algún debito no procesado para la empresa, lo que significa que no es
        -- un reproceso
        p_datos     := 'S';
        p_reprocesa := 'N';
        v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
        /*
 ---- verifico que no se haya procesado ya el dia de hoy
 --- RI 07/10/09 : Se comenta para llevar este control en el form, de manera
 -- de exhibir como una alerta y pedir confirmación del usuario
  declare
    v_procesado VARCHAR2(1) := 'S';
  begin
    select 'S'
     into v_procesado
     from ge_pag_sueldos_tmp a
    where ((cod_ente is null) or cod_ente = p_cod_ente)
      and tipo = 'D'
      and exists (select 0 from ge_pag_sueldos b
                   where b.cod_ente = p_cod_ente
                     and b.fec_proceso = v_fec_actual
                     and b.tipo = 'D'
                     and b.monto = a.monto
                     and cod_proceso = 0);
      raise_application_error(-20019,'El Ente ya fue procesado hoy. Verifique!');
  exception
    when no_data_found then null;
  end;
  */

-- RI : 12/05/2010: Ya No tiene sentido este select
        ---- voy a verificar si va a procesar la empresa verificada
/*   begin
     select min(cod_ente) into v_ente
       from ge_pag_sueldos_tmp
      where cod_ente = p_cod_ente;
     if v_ente <> p_cod_ente then
       RAISE_APPLICATION_ERROR(-20811,'El Ente : '||to_char(v_ente)||'aún no fue procesado. Verifique !!!'||sqlerrm);
     end if;
   exception
     when no_data_found then null;
     when others then null;
    end;*/
        ----
        SELECT FEC_PROCESO
        INTO p_fecha
        FROM GE_PAG_SUELDOS
        WHERE cod_ente = p_cod_ente
          AND tipo = 'D'
          AND COD_PROCESO   <> 0;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Se busca que exista algún credito sin procesar de la Empresa
            BEGIN
                SELECT DISTINCT FEC_PROCESO
                INTO p_fecha
                FROM GE_PAG_SUELDOS
                WHERE cod_ente = p_cod_ente
                  AND COD_PROCESO   <> 0;
                p_reprocesa := 'S';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    p_datos := 'N';
                WHEN TOO_MANY_ROWS THEN
                    p_reprocesa := 'S';
                    SELECT MIN(FEC_PROCESO)
                    INTO p_fecha
                    FROM GE_PAG_SUELDOS
                    WHERE cod_ente = p_cod_ente
                      AND COD_PROCESO <> 0;
            END;
        WHEN TOO_MANY_ROWS THEN
            -- Existe varios dias sin procesarse
            SELECT MIN(FEC_PROCESO)
            INTO p_fecha
            FROM GE_PAG_SUELDOS
            WHERE cod_ente = p_cod_ente
              AND COD_PROCESO   <> 0;
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20830,'En PR_VER_PAG_SUELDO . Verifique !!!'||sqlerrm);
    end pr_ver_pag_sueldo;
/* Procesa los movimientos */
    PROCEDURE PR_ACT_CRED_EMPLEADO
    (P_REPROCESO IN OUT VARCHAR2
    ,P_COD_ENTE IN NUMBER
    ,P_NRO_SECUENCIA IN OUT NUMBER
    ,P_CDOFICI IN NUMBER
    ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
    ,P_USUARIO IN VARCHAR2
    ,P_LUGAR IN OUT VARCHAR2
    ,P_HUBO_ERROR OUT VARCHAR2
    ,P_TIPO_TRA_PADRE IN VARCHAR2
    ,P_HOR_MOVIMIENTO IN VARCHAR2 DEFAULT NULL
    ,P_FEC_INSERCION IN GE_PAG_SUELDOS.FEC_INSERCION%TYPE DEFAULT NULL,
        p_nro_movimiento IN bw_movimientos.nro_movimiento%type default 0 /*BWP-37-glopez*/
    )
        IS
    begin
        declare
            v_fechamax   DATE;
            v_hrmovim    VARCHAR2(08);
            v_estpres  ba_modulos.estado%type;
            v_sec_sgt_movimiento number;
            v_mto_credito ge_pag_sueldos.monto%type;
            v_mto_debito  ge_pag_sue_lotes.mto_debito%type;
            v_error      VARCHAR2(4000);
            v_secuencia        ge_pag_sue_lotes.nro_secuencia%TYPE := p_nro_secuencia;
            v_pro_con_errores varchar2(1) := UPPER(fug_obt_parentes(P_COD_ENTE,'PRO_CON_ERRORES'));
            v_fecha date;
            v_cob_aut_atr_tarjetas ge_par_dinamicos.val_parametro%type;
            v_tar_cob_aut_atr_itgf ge_par_dinamicos.val_parametro%type;
            v_tar_cob_aut_atr_web  ge_par_dinamicos.val_parametro%type;
            v_cod_usu_hb       varchar2(30):= fug_obt_pardinamico('COD_USU_HOMEBANKING');

            CURSOR err (p_cod_ente ge_pag_sueldos.cod_ente%type,
                p_fec_proceso ge_pag_sueldos.fec_proceso%type,
                p_nro_secuencia ge_pag_sueldos.nro_secuencia%type) IS

                SELECT *
                FROM ge_pag_sueldos
                WHERE cod_ente = p_cod_ente
                  and trunc(fec_proceso) = trunc(p_fec_proceso)
                  and nro_secuencia = p_nro_secuencia
                  and tipo = 'C'
                  and nvl(cod_proceso,0) <> 0;

        BEGIN
            -- OMM 06/12/2010 Se modifico para pago de salarios via web
            if nvl(PAE_CNF.G_PROGRAMA,'x') = 'GPPAGSUE' then
                pae_cnf.PR_CTR_MODULO(3);
            end if ;
            --
            if p_hor_movimiento is not null then
                v_hrmovim := p_hor_movimiento;
            end if;
            -- OMM 30/09/2014. Si es Aguinaldo no realiza Cobro Parcial
            if p_tipo_tra_padre = 'A' then
                v_pro_con_errores := 'C';
            end if ;
            p_lugar := 'proc: PR_ACT_CRED_EMPLEADO :llama a LP_INS_MOV_SUELDO Procesar movimiento';

            PAG_SUE.LP_INS_MOV_SUELDO(p_hubo_error,v_hrmovim,p_reproceso,p_cod_ente,p_nro_secuencia,p_lugar,p_cdofici, p_fec_hoy, p_usuario,P_TIPO_TRA_PADRE,
                                      v_sec_sgt_movimiento,p_nro_movimiento);

            if p_hubo_error in ('N','C') and  p_tipo_tra_padre in ('S','A') then
                -- agregado para liquidar el anticipo y/o aguinaldo
                -- seteo las variables de hora y secuencia para el debito automatico
                pae_cnf.PR_SET_VARIABLES(v_hrmovim,v_sec_sgt_movimiento);
                begin
                    pr_liq_anticipos(p_cod_ente, p_tipo_tra_padre);
                EXCEPTION
                    when others then
                        v_error := sqlerrm;
                        p_lugar  := 'Liquidacion de Anticipos '||sqlerrm;
                        p_hubo_error := 'S';
                end;
                --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
            elsif p_hubo_error = 'S' then
                p_hubo_error := 'Z' ;
                p_lugar := ' Error detectado en LP_INS_MOV_SUELDO. Verifique!';
            else
                -- seteo las variables de hora y secuencia para el debito automatico
                pae_cnf.PR_SET_VARIABLES(v_hrmovim,v_sec_sgt_movimiento);
            end if;
            
            
              if coalesce(fug_obt_pardinamico('ACT_DEB_AUT_PAGSUE'), 'N') = 'S' then
              /* OMM 19/01/2015. Se realiza el proceso de Debito Automático en caso de Pagos On-line que no corresponda a Aguinaldo
                        y que sea via Web, en caso del Programa realiza el Debito automático en el Programa según indicación  */
              if p_hubo_error in ('N','C') and  p_tipo_tra_padre <> 'A' and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPAGSUE' then
                  pr_pro_deb_automatico(p_cod_ente, p_nro_secuencia, p_fec_hoy, v_error);

                  BEGIN
                      prt_deb_automatico(null, null, p_cod_ente, p_nro_secuencia, p_fec_hoy);
                  EXCEPTION
                      WHEN OTHERS THEN
                          v_error := substr('Tarjetas '||sqlerrm,1,4000);
                  END;

                  --Proyecto PCCDEEVO-1046 - Optimizacion--
                  v_cob_aut_atr_tarjetas := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_TARJETAS'), 'N');
                  v_tar_cob_aut_atr_itgf := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_ITGF'), 'N');
                  v_tar_cob_aut_atr_web  := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_WEB'), 'N');
                  if v_cob_aut_atr_tarjetas = 'S' then
                      if (((v_tar_cob_aut_atr_itgf = 'S') and (instr(upper(user),v_cod_usu_hb) = 0) and (nvl(pae_cnf.g_programa, 'X') = 'GPPAGSUE')) OR
                          ((v_tar_cob_aut_atr_web = 'S') and  (instr(upper(user),v_cod_usu_hb) >= 1))) then
                          prt_deb_automatico_atr(null, null, p_cod_ente, p_nro_secuencia, p_fec_hoy);
                      end if;
                  end if;
                  -----------------------------------------
              end if ;
            end if;
            IF p_hubo_error in('S')  THEN
                --p_lugar := 'proc: PR_ACT_CRED_EMPLEADO : llama a LP_INS_ERROR_PROCESO - cod error de proceso ';

                IF v_form != 'N' and nvl(v_pro_con_errores,'N') = 'C' THEN   -- SOLO SI ES DEL FORM
                    LP_INS_ERROR_PROCESO(p_cod_ente,p_Fec_hoy,p_lugar,p_nro_secuencia,p_usuario);
                    -- HAGO ROllback de todo
                    rollback;
                ELSIF P_HUBO_ERROR <> 'P' then
                    p_hubo_error:= 'N';
                END IF;
                -- borro los registros procesados
                --p_lugar := 'Borrando datos de ge_pag_sueldos';
                if nvl(v_pro_con_errores,'N') = 'C' then
                    delete from ge_pag_sueldos
                    where cod_ente  = p_cod_ente
                      and fec_proceso = p_fec_hoy
                      and nro_secuencia = p_nro_secuencia
                      and nvl(procesado,'N') = 'N';
                    -- hago commit de solo esta parte y luego se hace raise para que deshaga todo
                    commit;
                    --CAMBIOS ANA 20/06/2025
                    p_lugar := substr('PR_ACT_CRED_EMPLEADO - error en el procesamiento '|| fu_obt_ubicacion,1,200);
                    pag_sue.pr_ins_errores('CUENTA', p_cod_ente,trunc(p_fec_hoy),p_nro_secuencia,
                                                       null,null,'S',021,p_lugar);
                    raise_application_error(-20021,'Error en el Procesamiento. Verificar! ' || v_error||' '|| p_lugar);
                    --- ahora hago raise para que de el error y no deje procesado nada
                    raise_application_error(-20021,'Error en el Procesamiento. Verificar! ' || v_error||' '|| p_lugar);
                    --Verificar si el monto registrado corresponde a lo debitado
                else
                    PAG_SUE.LP_DEL_DATOS_TEMPORA(p_cod_ente, NVL(p_fec_insercion,p_Fec_hoy), p_lugar, p_nro_secuencia,p_usuario);

                    --recorro el cursor para ir insertando cada cuenta con error en la tabla de errores.
                    FOR c IN err (p_cod_ente, p_fec_hoy, p_nro_secuencia) LOOP
                            pag_sue.pr_ins_errores(c.nro_cuenta,
                                                   c.cod_ente,
                                                   c.fec_proceso,
                                                   c.nro_secuencia,
                                                   c.cod_moneda,
                                                   c.monto,
                                                   'C', --credito
                                                   '10',
                                                   'Error al acreditar en cuenta nro. '||c.nro_cuenta );
                        END LOOP;

                    delete from ge_pag_sueldos
                    where cod_ente  = p_cod_ente
                      and fec_proceso = p_fec_hoy
                      and nro_secuencia = p_nro_secuencia
                      and nvl(cod_proceso,0) <> 0;
                end if;

                /*IF v_form != 'N' THEN -- SOLO SI ES DEL FORM
      -- hago commit de solo esta parte y luego se hace raise para que deshaga todo
         commit;
      END IF;*/

                --- ahora hago raise para que de el error y no deje procesado nada
            ELSIF p_hubo_error in ('N','C') THEN
                if v_form = 'N' then
                    v_fecha := trunc(p_Fec_insercion);
                else
                    v_fecha := trunc(p_Fec_hoy);
                end if;
                PAG_SUE.LP_DEL_DATOS_TEMPORA(p_cod_ente,v_fecha /*NVL(p_fec_insercion,p_Fec_hoy)*/, p_lugar, p_nro_secuencia,p_usuario);
                p_lugar := 'proc: PR_ACT_CRED_EMPLEADO : Proceso Terminado sin Errores ....';
                if p_hubo_error = 'C' then
                    p_lugar := 'NO SE PUDO COBRAR LA COMISION...VERIFIQUE...';
                end if;
            ELSIF p_hubo_error = 'X' THEN --- quiso procesar otro ente distinto al verificado
                p_lugar := 'Trato de procesar otro Ente '; --- en el programa despliega el mensaje de error para no borrar datos del tmp
            ELSIF p_hubo_error = 'Z' THEN
                IF v_pro_con_errores = 'N' then
                    PAG_SUE.LP_DEL_DATOS_TEMPORA(p_cod_ente, NVL(p_Fec_hoy,p_fec_insercion), p_lugar, p_nro_secuencia,p_usuario);
                    delete from ge_pag_sueldos
                    where cod_ente  = p_cod_ente
                      and fec_proceso = p_fec_hoy
                      and nro_secuencia = p_nro_secuencia;
                    commit;
                    p_lugar := ' No se encuentran cuentas de Crédito. Verifique!';
                END IF;
            END IF;
        END;

    end pr_act_cred_empleado;
/* Inserta los movimientos */
    PROCEDURE LP_INS_MOV_SUELDO
    (P_HUBO_ERROR IN OUT VARCHAR2
    ,P_HORAMOV IN OUT VARCHAR2
    ,P_REPROCESO IN VARCHAR2
    ,P_COD_ENTE IN NUMBER
    ,P_NRO_SECUENCIA IN OUT NUMBER
    ,P_LUGAR IN OUT VARCHAR2
    ,P_CDOFICI IN NUMBER
    ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
    ,P_USUARIO IN VARCHAR2
    ,P_TIPO_TRA_PADRE IN VARCHAR2
    ,P_SEC_SGT_MOVIMIENTO OUT NUMBER
    ,p_nro_movimiento     IN bw_movimientos.nro_movimiento%type default 0 /*BWP-37-glopez*/
    )
        IS
    --PDSYP-452 Buscamos parametros utilizados para la notificacion   
    v_entes ge_par_dinamicos.val_parametro%TYPE := coalesce(fug_obt_pardinamico('HAB_NOT_ENTES'), ''); 
    v_hab_not  ge_par_dinamicos.val_parametro%TYPE := coalesce(fug_obt_pardinamico('HAB_NOT_PAG_SALARIO'), 'N');
    --PDSYP-452
    procedure lp_ins_notificaciones(lp_cod_ente it.ge_entes.cod_ente%type,
                                   lp_tipo_tra_padre varchar2,
                                   lp_nro_cuenta it.ge_cuentas.nro_cuenta%type) is
     v_cod_ente ge_par_dinamicos.val_parametro%type;                            
    begin
      --preparamos el ente
      v_cod_ente := '#'|| lp_cod_ente ||'#';
      
      if instr(v_entes, v_cod_ente) > 0 or 
         v_hab_not = 'S' then
         
         IF lp_tipo_tra_padre = 'A' then --- AGUINALDO
          it.PRW_INS_NOT_PAG_SUELDOS('aguinaldo', lp_nro_cuenta);
         ELSIF lp_tipo_tra_padre = 'S' then  ---- Salario
          it.PRW_INS_NOT_PAG_SUELDOS('salario', lp_nro_cuenta);                               
         END IF;
      
      end if;  
      
    exception
      when others then 
        null;
    end;                                   
        
        
    begin

        declare
            CURSOR Sdo IS
                SELECT p.rowid,
                       nro_secuencia,
                       p.nro_cuenta, tipo, DECODE(tipo,'D',503,'C',602,null),
                       monto, r.cod_modalidad, r.cod_modulo,fec_proceso, observacion nro_remito,
                       cod_moneda, p.nro_lote, p.procesado
                FROM GE_CTA_CLIENTES R, GE_PAG_SUELDOS P
                WHERE r.nro_cuenta = p.nro_cuenta
                  and cod_ente = p_cod_ente
                  and p.nro_secuencia = p_nro_secuencia
                  and relacion = 'P'
                  and nvl(cod_proceso,0) = 0
                  and fec_proceso = p_fec_hoy
                  and NVL(p.procesado,'N') != 'S'
                  AND NOT EXISTS
                    (SELECT 0
                     FROM ge_movimientos b
                     WHERE b.nro_cuenta = p.nro_cuenta
                       AND b.monto = p.monto
                       AND b.cod_transaccion = decode(p.tipo, 'D', 503, 'C', 602, NULL)
                       AND b.estado = 'N'
                       AND b.reversado = 'N'
                       AND b.nro_documento = p_cod_ente
                       and b.nro_documento2 = p.nro_lote)
                ORDER BY tipo DESC;

            v_cuenta              ge_cuentas.nro_cuenta%type;
            v_cuenta_db           ge_cuentas.nro_cuenta%type;
            v_tpmovim             VARCHAR2(01);
            v_cnmovim             ge_movimientos.concepto%type;
            v_mensaje_error       VARCHAR2(1000);
            v_proceso_ok          VARCHAR2(01);
            v_fila                VARCHAR2(18);
            v_mov_error           VARCHAR2(01);
            v_cdmoned             VARCHAR2(03);
            v_estado_nuevo        VARCHAR2(01);
            v_puede_procesar      VARCHAR2(01);
            v_tiene_tp            VARCHAR2(01);
            v_tpvlpor_com         VARCHAR2(01);
            v_tpvlpor_iva         VARCHAR2(01);
            v_fcproce             DATE;
            v_max_sec_use_fgdiari NUMBER(07) := 0;
            v_codigo_error        NUMBER(03);
            v_cdmodal             NUMBER(03);
            v_cdmodul             NUMBER(03);
            v_cdmodap             NUMBER(03);
            v_cdmodup             NUMBER(03);
            v_cdofici             NUMBER(03);
            v_cdofior             NUMBER(03);
            v_tranh               NUMBER(03);
            v_secuencia           NUMBER(03);
            v_Sldisp              NUMBER;
            v_sldisp_comb         number;
            v_valor_com           NUMBER;
            v_valor_iva           NUMBER;
            v_Cantcred            NUMBER(05);
            v_Total_Credito       NUMBER;
            v_Comision            NUMBER;
            v_Iva                 NUMBER;
            v_imtrans             NUMBER;
            v_contador            NUMBER :=0;
            rg_movs               ge_movimientos%rowtype;
            v_cod_mon_local       ba_monedas.cod_moneda%type;
            v_cdpers              ba_personas.cod_persona%type;
            v_nro_lote            NUMBER(15);
            v_procesado           VARCHAR2(01);
---* estas variables son para obtener los datos de empresa
            v_descrip varchar2(60);
            v_ctadbsu               ge_cuentas.nro_cuenta%type;
            v_tranpdb               ge_transacciones.cod_transaccion%type;
            v_cdtasas               ge_par_entes.val_parametro%type;
            v_cdtasas_iva           ge_par_entes.val_parametro%type;
            v_cdtriva               ge_transacciones.cod_transaccion%type;
            v_cdtrcom               ge_transacciones.cod_transaccion%type;
---*
            v_trancom               ge_transacciones.cod_transaccion%type;
            v_tranexc               ge_transacciones.cod_transaccion%type;
            v_tranpagui             ge_transacciones.cod_transaccion%type;
            v_tranpcom              ge_transacciones.cod_transaccion%type;
            v_tranpcre              ge_transacciones.cod_transaccion%type;
            v_tranpgra              ge_transacciones.cod_transaccion%type;---agr.p/pag.grat.
            v_deb_exceso            ge_par_entes.val_parametro%type;
            v_fec_inicio            ge_pag_sueldos.fec_proceso%type;
            v_fec_vencimiento       ge_pag_sueldos.fec_proceso%type;
            v_nro_cta_contable_txt  ge_par_entes.val_parametro%type;
            v_ser_activo            ge_par_entes.val_parametro%type;
            v_can_max_trans         ge_par_entes.val_parametro%type;
            v_precio_fijo           ge_par_entes.val_parametro%type;
            v_tra_aguinaldo         ge_par_entes.val_parametro%type;

---* para package de tasas
            v_g_cod_transaccion   ge_transacciones.cod_transaccion%type;
            v_g_tpvlpor           GE_TASAS.TIP_VALOR%TYPE;
            v_g_vltasa            GE_TAS_FECHAS.VAL_TASA%TYPE;
            v_g_fecha             GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
            v_g_tipo              GE_TASAS.TIPO%TYPE;
            v_g_cdmoned           VARCHAR2(03);
            v_ente                ge_entes.cod_ente%type;
            v_referencia_txt      varchar2(100);
            v_cantidad          number(10);
---* para obtener ley 125
            v_val_impuesto     number;
            v_tra_impuesto     ge_transacciones.cod_transaccion%type;
            v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
---v_impuesto         number(18,2);
            v_tot_debito       number;
            v_cta_ahorro       ge_cuentas.nro_cuenta%type;
            v_tot_imtrans      number;
            v_mto_max_comision number;
            v_remito           ge_pag_sueldos.observacion%type;
            v_nro_documento    number(15); -- OMM 20/10/2010
            v_est_modulo ba_modulos.estado%type; -- OMM 13/12/2010
            v_horario     varchar2(1)  := 'D'; -- Dia normal -- OMM 13/12/2010
            v_es_nocturno varchar2(1) := 'N'; -- No es Nocturno -- OMM 13/12/2010
            v_pro_con_errores   varchar2(1) := UPPER(nvl(fug_obt_parentes(P_COD_ENTE,'PRO_CON_ERRORES'),'N'));
            v_exi_error varchar2(1);
            v_moneda ge_pag_sueldos.cod_moneda%type;
            v_mto_credito ge_pag_sueldos.monto%type;
            v_mto_debito ge_pag_sue_lotes.mto_debito%type;
            v_mto_cre_error number(20);
            v_cta_ente ge_cuentas.nro_cuenta%type;
            v_cta_aguinaldo varchar2(1);
            v_mensaje number;

        BEGIN
            v_precio_fijo := fug_obt_parentes(p_cod_ente, 'COD_TRA_PRECIO_FIJO');
            v_mto_max_comision := fug_obt_parentes(p_cod_ente, 'MTO_MAX_COMISION');
            -- OMM 13/12/2010 Se modifico para pago de salarios via web en sistema cerrado
            if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPAGSUE' then
                v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
                If v_est_modulo = 2 then
                    v_horario := 'D' ; -- N=Cerrado, D=Abierto
                    v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
                else
                    v_horario := 'N' ; -- N=Cerrado, D=Abierto
                    v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
                end if;
                pag_cta.g_horario := v_horario;
            end if ;
----- trata de procesar otro ente , inserto datos de otro ente a verificar desde diskete ---
            begin
                select cod_ente into v_ente from ge_pag_sueldos where
                    cod_ente = p_cod_ente and rownum=1;
            exception
                when no_data_found then
                    p_hubo_error := 'X';
            end;
            if nvl(v_ente,0) <> p_cod_ente then
                p_hubo_error:= 'X';
                v_mov_error := 'S';
            else
                v_cnmovim := 'Pago de Sueldo ';
                --p_horamov := NULL;
                v_mov_error := 'N';
                p_hubo_error := 'N';

                PAG_SUE.PR_OBT_DATOS_EMPRESA(p_cod_ente,
                                             v_descrip,
                                             v_ctadbsu,
                                             v_tranpdb ,
                                             v_trancom,   ---v_cdtasas,
                                             v_tranexc,   ---v_cdtriva,
                                             v_tranpagui, ---v_cdtrcom,
                                             v_tranpcom,
                                             v_tranpcre,  --- Para RRHH se carga aqui el debito al Rubro
                                             v_tranpgra,   ---agr.p/pag.grat.
                                             v_deb_exceso,
                                             v_fec_inicio,
                                             v_fec_vencimiento,
                                             v_ser_activo,
                                             v_can_max_trans,
                                             v_nro_cta_contable_txt, ---Agregado para RRHH
                                             v_referencia_txt,
                                             p_lugar,
                                             p_fec_hoy,
                                             p_usuario);


                --- POR DEFECTO LA TRANS. PADRE ES SUELDO (S) SINO UNO DE LOS SGTES.
                v_tra_aguinaldo := 'N';
                IF P_TIPO_TRA_PADRE = 'A' then --- AGUINALDO
                    v_tranpdb := v_tranpagui;
                    v_cnmovim := 'Pago de Aguinaldo ';
                    v_tra_aguinaldo := fug_obt_parentes(p_cod_ente, 'PAG_TRA_AGUINALDO');
                    v_pro_con_errores := 'C'; -- OMM 30/09/2014. Aguinaldo no se realiza pago Parcial
                ELSIF P_TIPO_TRA_PADRE = 'C' then  ---- COMISION
                    v_tranpdb := v_tranpcom;
                    v_cnmovim := 'Pago de Comision ';
                ELSIF P_TIPO_TRA_PADRE = 'T' then  --- CREDITO
                    v_tranpdb := v_tranpcre;
                    v_cnmovim := 'Credito en Cuenta ';
                ELSIF P_TIPO_TRA_PADRE = 'G' then  --- GRATIFICACION
                    v_tranpdb := v_tranpgra;
                    v_cnmovim := 'Gratificacion del Empleado ';
                END IF;

                /* 07/11/2014 - OMM. Se comenta la obtención de hora, ya que se obtiene de la función de hora disponible
   IF p_Reproceso = 'S' THEN
      PAG_SUE.LP_OBT_HORA_MOVIM(p_horamov,p_fec_hoy,v_tranpdb,p_lugar );
   END IF;*/
                -- obtiene una hora unica para todos los movimientos a ser insertados
                IF p_horamov IS NULL THEN
                    p_horamov := TO_CHAR(SYSDATE,'HH24:MI:SS');
                END IF;
                p_horamov := fug_obt_hor_disponible(P_FEC_HOY,p_horamov,user,v_es_nocturno);
                --
                v_tot_imtrans := 0;
                IF Sdo%ISOPEN THEN
                    CLOSE Sdo;
                END IF;
                OPEN Sdo;
                LOOP
                    FETCH Sdo INTO v_fila, v_secuencia, v_cuenta, v_tpmovim, v_tranh, v_imtrans,
                        v_cdmodal, v_cdmodul,v_fcproce, v_remito,v_moneda,v_nro_lote,v_procesado ;
                    EXIT WHEN Sdo%NOTFOUND; --OR p_hubo_error = 'S';
                    p_lugar := 'Procesando Pago Sueldo Cuenta :'||v_cuenta;
                    ---
                    v_mov_error := 'N';
                    ---
                    -- OMM 20/10/2010 Se agrego secuencia para poder ingresar mas de 1 pago x dia
                    v_nro_documento := to_number(v_secuencia||p_cod_ente) ;
                    IF v_cdmodup IS NULL THEN
                        ---
                        if v_nro_cta_contable_txt is null then --- agregado para modulo de RRHH
                            begin
                                SELECT A.nro_cuenta,B.cod_moneda,B.cod_oficina
                                INTO v_cuenta_db,v_cdmoned,v_cdofici
                                FROM ge_pag_sueldos A,ge_cuentas B
                                WHERE A.nro_cuenta = B.nro_cuenta
                                  AND A.cod_modulo = B.cod_modulo
                                  AND A.cod_modalidad = B.cod_modalidad
                                  AND A.cod_ente = p_cod_ente
                                  AND A.tipo = 'D'
--                   AND A.nro_cuenta    = v_ctadbsu
                                  AND A.nro_secuencia = v_secuencia
                                  AND A.fec_proceso   = v_fcproce;
                            exception
                                when no_data_found then
                                    p_hubo_error:= 'S';
                                    v_mov_error := 'S';
                                    lp_act_ge_pag_sueldos(p_cod_ente,v_fcproce, v_secuencia, v_ctadbsu, 12);
                                /*                UPDATE ge_pag_sueldos
                      SET cod_proceso = 12
                    WHERE nro_cuenta=v_ctadbsu
                      and cod_ente = p_cod_ente
                      and fec_proceso = v_fcproce;*/
                                when too_many_rows then
                                    RAISE_APPLICATION_ERROR(-20909,'Error: Ya se proceso el Ente' );
                            end;
                            --
                            begin
                                SELECT cod_modulo, cod_modalidad, p_cdofici
                                INTO v_cdmodup, v_cdmodap, v_cdofior
                                FROM ge_cta_clientes
                                WHERE nro_cuenta = v_cuenta_db
                                  AND relacion = 'P';
                            exception
                                when others then
                                    p_hubo_error:= 'S';
                                    v_mov_error := 'S';
                                    lp_act_ge_pag_sueldos(p_cod_ente,v_fcproce, v_secuencia, v_ctadbsu, 12);
                                /*              UPDATE ge_pag_sueldos
                     SET cod_proceso = 12
                   WHERE nro_cuenta=v_ctadbsu
                     and cod_ente = p_cod_ente
                     and fec_proceso = v_fcproce;*/
                            end;
                            ---
                        else
                            --- agregado para RRHH
                            -- OMM Se modifico la oficina por problemas de interoficinas en pago de salarios BBVA
                            begin
                                SELECT B.cod_moneda,r.cod_oficina
                                INTO v_cdmoned, v_cdofior
                                FROM ge_cuentas B, ge_cta_clientes c, rh_empleados r
                                WHERE B.nro_cuenta = v_cuenta
                                  and B.nro_cuenta = c.nro_cuenta
                                  and c.cod_persona = r.cod_persona;
                            exception
                                when others then
                                    p_hubo_error:= 'S';
                                    v_mov_error := 'S';
                                    --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                                    v_mensaje_error := 'Cuenta '||v_cuenta||' Error al Consultar tabla Empleados';

                                    UPDATE ge_pag_sueldos_tmp
                                    SET cod_proceso = 20 WHERE nro_cuenta=v_cuenta;

                                    --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                                    pag_sue.pr_ins_errores(v_cuenta,
                                                           p_cod_ente,
                                                           v_fcproce,
                                                           v_secuencia,
                                                           v_moneda,
                                                           v_imtrans,
                                                           'C', --credito
                                                           '20',
                                                           'Error al Consultar tabla Empleados cuenta nro. '||v_cuenta);

                            end;
                            ---
                            begin
                                SELECT cod_modulo, cod_modalidad, cod_oficina --p_cdofici OMM
                                INTO v_cdmodup, v_cdmodap, v_cdofici
                                FROM ge_cta_clientes
                                WHERE nro_cuenta = v_cuenta
                                  AND relacion = 'P';
                            exception
                                when others then
                                    p_hubo_error:= 'S';
                                    v_mov_error := 'S';
                                    --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                                    UPDATE ge_pag_sueldos_tmp
                                    SET cod_proceso = 12 WHERE nro_cuenta=v_cuenta;

                                    v_mensaje_error := 'Cuenta '||v_cuenta||' Error al Consultar Cta. Clientes ';

                                    --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                                    pag_sue.pr_ins_errores(v_cuenta,
                                                           p_cod_ente,
                                                           v_fcproce,
                                                           v_secuencia,
                                                           v_moneda,
                                                           v_imtrans,
                                                           'C', --credito
                                                           '12',
                                                           'Error al Consultar Cta. Clientes cuenta nro. '||v_cuenta);

                            end;
                        end if;

                    END IF;
                    --
                    if v_mov_error = 'N' then
                        p_lugar := p_lugar||' LP_INS_MOV_SUELDO llama al pack: PAG_CTA.PR_ACT_OPERACION ';
                        ---
                        if v_nro_cta_contable_txt is not null then
                            --- Agregado para modulo de RRHH
                            --- Para grabar por cada registro procesado y sus movimientos la misma hora
                            --v_fcproce := pag_cal.FU_OBT_FEC_ACTUAL(pag_cta.g_ctas.cod_modulo);
                            --p_horamov := pag_gen.fu_obt_sig_segundo(p_horamov);
                            v_cdmodup := 14;
                            v_cdmodap := 141;
                        end if;
                        /* RI : 25/11/2009 : Si el tipo de movimiento es Aquinaldo y si el ente esta
            configurado con Traspaso de Cta.Cte a Caja de Ahorro, verificar antes
            de acreditar en la cuenta cte. que existe la Caja de ahorro de manera que no acredite
            nada y marcar el registro con el error */
                        -- Se invoca al procedimiento que verifica si existe error en alguna cuenta de aguinaldo
                        --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                        if p_hubo_error = 'N' then
                            if v_tpmovim = 'C' and P_TIPO_TRA_PADRE = 'A' THEN
                                PAG_SUE.PR_VER_CTA_AGUINALDO(P_COD_ENTE,TRUNC(v_fcproce),v_mensaje_error,v_Codigo_Error,v_mov_error,v_cuenta,v_secuencia, v_pro_con_errores,v_imtrans,v_moneda,v_cta_ahorro,v_tpmovim,v_cta_aguinaldo);
                                IF v_mov_error = 'N' then
                                    v_mov_error:= 'S';
                                    p_hubo_error:= 'S';
                                ELSE
                                    v_mov_error:= 'N';
                                    p_hubo_error:= 'N';
                                END IF;
                            end if;
                        end if;
                        --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                        -- Aqui se debe verificar si alguna cuenta de crédito tiene error.
                        if v_tpmovim = 'C' and v_pro_con_errores = 'N' and p_hubo_error = 'N' THEN
                            PAG_CTA.PR_VER_OPERACION(v_cuenta,
                                                     v_tranpdb,
                                                     v_cdmodup,
                                                     v_cdmodap,
                                                     v_tpmovim,
                                                     v_cdmoned,
                                                     v_imtrans,
                                                     v_cdofior,
                                                     v_cdmodul,
                                                     v_cdmodal,
                                                     v_estado_nuevo,
                                                     v_sldisp,
                                                     v_puede_procesar);

                            v_mensaje_error := pag_cta.fu_obt_msj_error;
                            v_codigo_error := pag_cta.fu_obt_cod_error;
                            if v_codigo_error > 0 then
                                lp_act_ge_pag_sueldos(p_cod_ente,v_fcproce, v_secuencia, v_cuenta,v_codigo_error);
                            end if;
                        end if;
                        -- FQ Acumulo el total del credito para que se realice el débito por el monto
                        -- de cuentas sin error. BBVADES 2576

                        if v_tpmovim = 'D' and v_pro_con_errores = 'N' and p_hubo_error = 'N' then
                            v_cta_ente:= v_cuenta;
                            p_horamov := TO_CHAR(SYSDATE,'HH24:MI:SS');

                            begin
                                SELECT sum(monto)
                                INTO v_imtrans
                                FROM GE_CTA_CLIENTES R, GE_PAG_SUELDOS P
                                WHERE r.nro_cuenta = p.nro_cuenta
                                  and cod_ente = p_cod_ente
                                  and p.nro_secuencia = p_nro_secuencia
                                  and relacion = 'P'
                                  and nvl(cod_proceso,0) = 0
                                  and p.tipo = 'C'
                                  and fec_proceso = p_fec_hoy;
                            exception
                                when no_data_found then
                                    RAISE_APPLICATION_ERROR(-20500,'No se encuentran cuentas de Crédito a Procesar.');
                            end;
                        else
                            --para que sume 1 segundo a cada movimiento de reversión(sueldo,aguinaldo,credito,comision)
                            p_horamov    := pag_gen.fu_obt_sig_segundo(p_horamov);
                        end if;

                        If v_mov_error = 'N' and v_imtrans > 0  then
                            -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                            if v_max_sec_use_fgdiari > 990 then
                                v_max_sec_use_fgdiari := -999;
                            elsif v_max_sec_use_fgdiari < 0 and v_max_sec_use_fgdiari > -10 then
                                --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                                p_horamov := fug_obt_hor_disponible(v_fcproce,p_horamov,user,v_es_nocturno);
                                v_max_sec_use_fgdiari := 0 ;
                            end if;
                            if p_cierre = 'N' then
                                pag_sue.pr_ins_log(v_cuenta,v_imtrans,'LP_INS_MOV_SUELDO','Actualización Saldo Cta. crédito');
                            end if;
                            --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                            if nvl(p_nro_movimiento,0) <> 0 then
                                v_nro_documento := p_nro_movimiento ||'070';
                            end if;
                            IF nvl(v_cta_aguinaldo,'N') = 'N'  and p_hubo_error = 'N' then

                                pag_cta.PR_SET_NRO_DOCUMENTO3(p_cod_ente);

                                pag_cta.pr_set_variables(user, v_fcproce, v_tranpdb,
                                                         'N', 'N', v_max_sec_use_fgdiari, NULL,
                                                         v_cdofior, v_cdmodup, v_cdmodap);


                                PAG_CTA.PR_ACT_OPERACION(v_cuenta,
                                                         p_horamov,
                                                         v_tpmovim,
                                                         v_cdmoned,
                                                         v_imtrans,
                                                         v_tranpdb,
                                                         v_tranh,
                                                         nvl(v_remito,v_nro_documento), --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                         NULL,
                                                         v_cdofior,
                                                         v_cdmodup,
                                                         v_cdmodap,
                                                         NULL,
                                                         NULL,
                                                         v_cnmovim,
                                                         'S',
                                                         v_max_sec_use_fgdiari,
                                                         v_fcproce);
                                --
                                v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                                v_mensaje_error := pag_cta.fu_obt_msj_error;
                                v_codigo_error  := pag_cta.fu_obt_cod_error;
                                --actualiza ge_movimientos por cada fila con el nro de lote correspondiente
                                UPDATE GE_MOVIMIENTOS
                                SET nro_documento2 = v_nro_lote
                                WHERE nro_cuenta = v_cuenta
                                  and hora = p_horamov
                                  and cod_tra_padre = v_tranpdb
                                  and nro_documento3 = p_cod_ente
                                  and cod_mod_padre = v_cdmodup
                                  and cod_mad_padre = v_cdmodap
                                  and fecha = v_fcproce;
                                lp_act_ge_pag_sueldos(v_fila, v_codigo_error);

                                if  v_proceso_ok = 'S' then
                                    /*  update ge_movimientos
                       set nro_documento3 = p_cod_ente
                      where hora = p_horamov
                        --and cod_usuario = user
                       and usu_insercion = user
                       and cod_tra_padre = v_tranpdb
                       and cod_transaccion = v_tranh
                       and nro_cuenta = v_cuenta;  */
                                    --RI : 30/11/09 : Acumulo el total de creditos para luego tener en cuenta para generar
                                    -- la comision, si el monto total acreditardo es cero no generar comision
                                    If  v_tpmovim = 'C' then
                                        v_tot_imtrans := nvl(v_tot_imtrans,0) + nvl(v_imtrans,0);
                                    end if;
                                  
                                else
                                    p_hubo_error:= 'S';
                                    v_mov_error := 'S';
                                    P_LUGAR := v_mensaje_error;
                                end if;
                            else
                                v_proceso_ok := 'S';
                            end if;
                            ---RI: 25/11/09 : Si es aguinaldo y si el ente tiene configurado,
                            -- realizar la transferencia de la cta.cte. a la caja de ahorro
                            If v_proceso_ok = 'S'
                                and v_tpmovim = 'C'
                                and P_TIPO_TRA_PADRE = 'A' -- Aguinaldo
                                and v_tra_aguinaldo  = 'S' THEN
                                --and  v_mto_credito > 0 then
                                -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                                if v_max_sec_use_fgdiari > 990 then
                                    v_max_sec_use_fgdiari := -999;
                                elsif v_max_sec_use_fgdiari < 0 and v_max_sec_use_fgdiari > -10 then
                                    --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                                    p_horamov := fug_obt_hor_disponible(v_fcproce,p_horamov,user,v_es_nocturno);
                                    v_max_sec_use_fgdiari := 0 ;
                                end if;

                                if p_cierre = 'N' then
                                    pag_sue.pr_ins_log(v_cuenta,v_imtrans,'LP_INS_MOV_SUELDO','Débito de la cuenta origen cuando es cuenta de aguinaldo');
                                end if;
                                --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                                if nvl(v_cta_aguinaldo,'N') = 'N'  and p_hubo_error = 'N' then
                                    --- Debitar de la cuenta origen

                                    pag_cta.pr_set_variables(user, v_fcproce, v_tranpdb,
                                                             'N', 'N', v_max_sec_use_fgdiari, NULL,
                                                             v_cdofior, v_cdmodup, v_cdmodap);


                                    PAG_CTA.PR_ACT_OPERACION(v_cuenta,
                                                             p_horamov,
                                                             'D',
                                                             v_cdmoned,
                                                             v_imtrans,
                                                             v_tranpdb,
                                                             503,  --debito de la cuenta origen
                                                             nvl(v_remito,v_nro_documento), --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                             NULL,
                                                             v_cdofior,
                                                             v_cdmodup,
                                                             v_cdmodap,
                                                             NULL,
                                                             NULL,
                                                             v_cnmovim,
                                                             'S',
                                                             v_max_sec_use_fgdiari,
                                                             v_fcproce);
                                    --
                                    v_proceso_ok    := pag_cta.fu_obt_ok_procesar;

                                    v_codigo_error  := pag_cta.fu_obt_cod_error;
                                    if v_codigo_error = 25 then
                                        v_mensaje_error := 'Cuenta '||v_cuenta||' con Saldo Insuficiente p/ el débito de GS '||v_imtrans;
                                        p_hubo_error:= 'S';
                                        v_mov_error := 'S';
                                    else
                                        v_mensaje_error := pag_cta.fu_obt_msj_error;
                                    end if;

                                    lp_act_ge_pag_sueldos(v_fila, v_codigo_error);
                                else
                                    v_proceso_ok:= 'S';
                                end if;
                                --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                                if  v_proceso_ok = 'S'  and p_hubo_error = 'N' then
                                    /*update ge_movimientos
                      set nro_documento3 = p_cod_ente
                     where hora = p_horamov
                       --and cod_usuario = user
                      and usu_insercion = user
                      and cod_tra_padre = v_tranpdb
                      and cod_transaccion = 503
                      and nro_cuenta = v_cuenta;  */
                                    -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                                    if v_max_sec_use_fgdiari > 990 then
                                        v_max_sec_use_fgdiari := -999;
                                    elsif v_max_sec_use_fgdiari < 0 and v_max_sec_use_fgdiari > -10 then
                                        --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                                        p_horamov := fug_obt_hor_disponible(v_fcproce,p_horamov,user,v_es_nocturno);
                                        v_max_sec_use_fgdiari := 0 ;
                                    end if;

                                    -- Acreditar en la cuenta de Ahorro
                                    if p_cierre = 'N' then
                                        pag_sue.pr_ins_log(v_cta_ahorro,v_imtrans,'LP_INS_MOV_SUELDO','Crédito en la cuenta de Ahorro Aguinaldo');
                                    end if;
                                    pag_cta.pr_set_variables(user, v_fcproce, v_tranpdb,
                                                             'N', 'N', v_max_sec_use_fgdiari, NULL,
                                                             v_cdofior, v_cdmodup, v_cdmodap);


                                    PAG_CTA.PR_ACT_OPERACION(v_cta_ahorro,
                                                             p_horamov,
                                                             'C',
                                                             v_cdmoned,
                                                             v_imtrans,
                                                             v_tranpdb,
                                                             602,  --credito en la cuenta destino
                                                             nvl(v_remito,v_nro_documento), --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                             NULL,
                                                             v_cdofior,
                                                             v_cdmodup,
                                                             v_cdmodap,
                                                             NULL,
                                                             NULL,
                                                             v_cnmovim,
                                                             'S',
                                                             v_max_sec_use_fgdiari,
                                                             v_fcproce);
                                    --
                                    v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                                    --v_mensaje_error := pag_cta.fu_obt_msj_error;
                                    v_codigo_error  := pag_cta.fu_obt_cod_error;
                                    if v_codigo_error = 25 then
                                        v_codigo_error:= 73;
                                        v_mensaje_error := 'Cuenta '||v_cuenta||' no permite crédito concepto Aguinaldo p/ el débito de GS '||v_imtrans;
                                    else
                                        v_mensaje_error := pag_cta.fu_obt_msj_error;
                                    end if;
                                    lp_act_ge_pag_sueldos(v_fila, v_codigo_error);
                                    if v_proceso_ok = 'S' then
                                        null;/*
                       update ge_movimientos
                          set nro_documento3 = p_cod_ente
                        where hora = p_horamov
                           --and cod_usuario = user
                          and usu_insercion = user
                          and cod_tra_padre = v_tranpdb
                          and cod_transaccion = 602
                          and nro_cuenta = v_cta_ahorro;*/
                                    else
                                        p_hubo_error:= 'S';
                                        P_LUGAR := v_mensaje_error;
                                        v_mov_error := 'S';
                                    End if;

                                else
                                    p_hubo_error:= 'S';
                                    v_mov_error := 'S';
                                End if;
                            end if;
                        End if;
                    End if;
                    IF v_proceso_ok = 'N' AND v_tpmovim = 'D' THEN
                        p_hubo_error:= 'S';
                        v_mov_error := 'S';
/*            ELSE
               UPDATE GE_PAG_SUELDOS
                SET FEC_PROCESO = p_fec_hoy
              WHERE ROWID = v_fila;*/
                    ELSIF v_proceso_ok = 'S' then -- CAN-NOTIFICACIONES Fase 2
                        
                        v_cdpers := FUG_OBT_CLI_PRINCIPAL(v_cuenta);
                        
                        IF p_tipo_tra_padre = 'A' and v_cta_ahorro is not null then
                            v_cuenta := v_cta_ahorro;
                        END IF;
                        begin
                          --glopez PDSYP-452
                          if v_tpmovim = 'C' then
                             lp_ins_notificaciones(P_COD_ENTE,
                                                  P_TIPO_TRA_PADRE,
                                                  v_cuenta);
                                               
                          end if;
                        exception 
                          when others then
                            null;
                        end;
 
                        v_mensaje := PAW_NOT.fu_not_pag_sueldo(v_cdpers, --Código de Persona
                                                               v_cuenta, --Número de Cuenta
                                                               v_cdmoned, --Código de la Moneda
                                                               v_imtrans, --Monto de la Acreditación
                                                               p_tipo_tra_padre); --Tipo de Pago de Sueldos
                    END IF;
                    EXIT WHEN p_hubo_error > 'S';
                END LOOP;

                IF Sdo%ISOPEN THEN
                    CLOSE Sdo;
                END IF;
--   p_hubo_error    := v_mov_error;
                v_cod_mon_local := pag_gen.fu_obt_mon_local;
                v_Sldisp      := 0;
                v_Sldisp_comb := 0;

                begin
                    select nvl(sum(monto),0)
                    into v_mto_credito
                    from ge_pag_sueldos
                    where cod_ente = p_cod_ente
                      and fec_proceso = P_FEC_HOY
                      and nro_secuencia = p_nro_secuencia
                      and tipo = 'C'
                      and nvl(cod_proceso,0) = 0;
                exception
                    when no_data_found then
                        P_HUBO_ERROR:= 'Z';
                end;
                if nvl(v_mto_credito,0) = 0 then
                    P_HUBO_ERROR:= 'Z';
                end if;

                IF nvl(p_hubo_error,'N') = 'N' and v_mto_credito > 0  THEN
                    ---
                    --- agregado para modulo de RRHH
                    ---
                    if v_nro_cta_contable_txt is null then
                        p_lugar := 'LP_INS_MOV_SUELDO llama al pack. PAG_CTA.PR_VER_OPERACION)';
                        PAG_CTA.PR_VER_OPERACION(v_ctadbsu,
                                                 v_tranpdb,
                                                 v_cdmodul,
                                                 v_cdmodal,
                                                 'D',
                                                 v_cdmoned,
                                                 1,
                                                 v_cdofior,
                                                 v_cdmodup,
                                                 v_cdmodap,
                                                 v_estado_nuevo,
                                                 v_sldisp,
                                                 v_puede_procesar);
                        v_mensaje_error := pag_cta.fu_obt_msj_error;
                        v_codigo_error := pag_cta.fu_obt_cod_error;

                        v_sldisp_comb := pag_cta.fu_sal_dis_combinada; --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                        --
                        p_lugar := 'EN Proc : LP_INS_MOV_SUELDO llama al proc. lp_obt_datos_cuenta ';
                        PAG_SUE.LP_OBT_DATOS_CUENTA(v_ctadbsu, v_tiene_tp, v_cdmoned, p_lugar);

                        p_lugar := 'EN Proc : LP_INS_MOV_SUELDO llama al proc. lp_obt_monto_proc ';
                        PAG_SUE.LP_OBT_MONTO_PROC(v_Secuencia, p_cod_ente, v_CantCred, v_Total_Credito,P_lugar,p_fec_hoy);

                        ----- A PARTIR DE AQUI DEBE HACER EL PRG_OBT_CARGOS
                        ----------------------------------------------
                        -----Calcula Comision e Iva para La Empresa --
                        ----------------------------------------------
                        If  v_trancom is not null and v_tot_imtrans > 0 then
                            PRG_OBT_CARGOS
                            (v_cdofior            --P_COD_OFI_ORIGEN     IN GE_CUENTAS.COD_OFICINA%TYPE
                                ,v_ctadbsu            --P_NRO_CUENTA         IN GE_CUENTAS.NRO_CUENTA%TYPE
                                ,v_cdmoned            --P_COD_MONEDA         IN GE_CUENTAS.COD_MONEDA%TYPE
                                ,v_Total_Credito      --P_MONTO              IN GE_MOVIMIENTOS.MONTO%TYPE
                                ,v_cdmodup            --P_COD_MODULO         IN GE_CUENTAS.COD_MODULO%TYPE
                                ,v_cdmodap            --P_COD_MODALIDAD      IN GE_CUENTAS.COD_MODALIDAD%TYPE
                                ,v_trancom            --P_COD_TRA_CARGO      IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
                                ,v_cdtasas            --P_COD_TAS_CARGO      OUT GE_MOVIMIENTOS.COD_TASA%TYPE
                                ,v_valor_com          --P_VAL_TAS_CARGO      OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                                ,v_comision           --P_VAL_CARGO          OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                                ,v_cdtriva            --P_COD_TRA_IMPUESTO   OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
                                ,v_cdtasas_iva        --P_COD_TAS_IMPUESTO   OUT GE_MOVIMIENTOS.COD_TASA%TYPE
                                ,v_valor_iva          --P_VAL_TAS_IMPUESTO   OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                                ,v_iva );             -- P_VAL_IMPUESTO      OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                            --- si el precio es fijo, la comision deber ser igual ---
                            if nvl(v_precio_fijo,'N') = 'S' then
                                v_comision := v_comision;
                            else
                                --- si es valor debe multiplicar por la cant. de creditos ---
                                if v_valor_com = nvl(v_comision,0) + nvl(v_iva,0) then
                                    v_tot_debito := (nvl(v_comision,0) + nvl(v_iva,0)) * nvl(v_cantcred,0);
                                    -- RI : 07/12/09 : Si esta parametrizado el monto maximo de comision que se puede
                                    -- cobrar al ente ajustar la comision a esta monto.
                                    if  nvl(v_tot_Debito,0) > nvl(v_mto_max_comision,0)
                                        and nvl(v_mto_max_comision,0) > 0  then
                                        v_tot_debito := v_mto_max_comision;
                                    End if;
                                    --
                                    if v_cdmoned = v_cod_mon_local then
                                        v_iva := round((v_tot_debito * nvl(v_valor_iva,0) / (nvl(v_valor_iva,0) + 100)),0);
                                    else
                                        v_iva := round((v_tot_debito * nvl(v_valor_iva,0) / (nvl(v_valor_iva,0) + 100)),2);
                                    end if;
                                    v_comision := v_tot_debito - v_iva;
                                    --v_iva := v_iva * v_cantcred;
                                end if;
                            end if;
/*        --- BUSCO IMPUESTO LEY 125 ---
        PAG_PRV.pr_obt_impuesto
       (v_cdofici              ---   IN GE_CUENTAS.COD_OFICINA%TYPE
       ,v_cuenta               ---   IN GE_CUENTAS.NRO_CUENTA%TYPE
       ,v_cdmoned               ---   IN GE_CUENTAS.COD_MONEDA%TYPE
       ,v_total_credito         ---   IN GE_MOVIMIENTOS.MONTO%TYPE
       ,v_cdmodup               ---   IN GE_CUENTAS.COD_MODULO%TYPE
       ,v_cdmodap               ---   IN GE_CUENTAS.COD_MODALIDAD%TYPE
       ,v_tra_impuesto         ---  OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
       ,v_cod_tas_impuesto     ---  OUT GE_MOVIMIENTOS.COD_TASA%TYPE
       ,v_val_impuesto         ---  OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
       ,v_impuesto );          ---   OUT GE_MOVIMIENTOS.VAL_TASA%TYPE

*/
                            p_lugar := 'EN Proc : LP_INS_MOV_SUELDO - Procesar_Movim.Sueldo - Busca Tasa Comision-Empresa';
                            ---* aqui verifico si no supera monto+iva lo disponible antes de generar mov 16/02/05
                            IF  NVL(v_SlDisp,0)+nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(v_ctadbsu),0) <  NVL(v_comision,0) + NVL(v_iva,0)  then
                                v_sldisp := v_sldisp_comb;
                                IF NVL(v_SlDisp,0)+nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(v_ctadbsu),0) <  NVL(v_comision,0) + NVL(v_iva,0)  then
                                    p_hubo_error:= 'S';
                                    lp_act_ge_pag_sueldos(p_cod_ente,v_fcproce, v_secuencia, v_ctadbsu, 25);
                                END IF;
                            END IF;
                            IF  nvl(p_hubo_error,'N') = 'N' then
                                ---*
--      IF  NVL(v_SlDisp,0) >= NVL(v_comision,0) + NVL(v_iva,0) AND
--            NVL(v_comision,0) + NVL(v_iva,0) > 0 THEN
                                IF  NVL(v_SlDisp,0)+nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(v_ctadbsu),0)
                                        >= NVL(v_comision,0) + NVL(v_iva,0)     AND
                                    NVL(v_comision,0) + NVL(v_iva,0) > 0 THEN
                                    --
                                    v_cnmovim := 'Comision pago de Sueldo';
                                    --
                                    If v_comision > 0 then
                                        -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                                        if v_max_sec_use_fgdiari > 990 then
                                            v_max_sec_use_fgdiari := -999;
                                        elsif v_max_sec_use_fgdiari < 0 and v_max_sec_use_fgdiari > -10 then
                                            --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                                            p_horamov := fug_obt_hor_disponible(v_fcproce,p_horamov,user,v_es_nocturno);
                                            v_max_sec_use_fgdiari := 0 ;
                                        end if;
                                        p_lugar := 'EN Proc : LP_INS_MOV_SUELDO llama al pack: PAG_CTA.PR_ACT_OPERACION : pago sueldo';
                                        p_horamov := TO_CHAR(SYSDATE,'HH24:MI:SS');
                                        if p_cierre = 'N' then
                                            pag_sue.pr_ins_log(v_ctadbsu,v_comision,'LP_INS_MOV_SUELDO','Cobro de comisión al ente');
                                        end if;


                                        pag_cta.pr_set_variables(user, v_fcproce, v_tranpdb,
                                                                 'N', 'N', v_max_sec_use_fgdiari, NULL,
                                                                 v_cdofior, v_cdmodup, v_cdmodap);

                                        PAG_CTA.PR_ACT_OPERACION(v_ctadbsu,
                                                                 p_horamov,
                                                                 'D',
                                                                 v_cdmoned,
                                                                 v_comision,
                                                                 v_tranpdb,
                                                                 v_trancom,  ---v_cdtrcom,
                                                                 nvl(v_remito,v_nro_documento), --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                                 NULL,
                                                                 nvl(v_cdofior,p_cdofici),
                                                                 v_cdmodup,
                                                                 v_cdmodap,
                                                                 NULL,
                                                                 NULL,
                                                                 v_cnmovim,
                                                                 'S',
                                                                 v_max_sec_use_fgdiari,
                                                                 v_fcproce);

                                        v_mensaje_error:=pag_cta.fu_obt_msj_error;
                                        v_proceso_ok:=pag_cta.fu_obt_ok_procesar;
                                        v_codigo_error:=pag_cta.fu_obt_cod_error;
                                        --actualiza ge_movimientos por cada fila con el nro de lote correspondiente
                                        UPDATE GE_MOVIMIENTOS
                                        SET nro_documento2 = v_nro_lote
                                        WHERE nro_cuenta = v_ctadbsu
                                          and hora = p_horamov
                                          and cod_tra_padre = v_tranpdb
                                          and nro_documento3 = p_cod_ente
                                          and cod_mod_padre = v_cdmodup
                                          and cod_mad_padre = v_cdmodap
                                          and fecha = v_fcproce;

                                        if v_proceso_ok!='S' then
                                            RAISE_APPLICATION_ERROR(-20500,'Error en pr_act_operacion: '||v_codigo_error||v_mensaje_error);
                                            /*else
               update ge_movimientos
                  set nro_documento3 = p_cod_ente
                where hora = p_horamov
                   --and cod_usuario = user
                  and usu_insercion = user
                  and cod_tra_padre = v_tranpdb
                  and cod_transaccion = v_trancom
                  and nro_cuenta = v_ctadbsu;  */
                                        end if;
                                    End if;
                                    --
                                    If  nvl(v_iva,0) > 0 then
                                        v_cnmovim := 'Iva s/Imp.pago de Sueldo';
                                        --
                                        -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                                        if v_max_sec_use_fgdiari > 990 then
                                            v_max_sec_use_fgdiari := -999;
                                        elsif v_max_sec_use_fgdiari < 0 and v_max_sec_use_fgdiari > -10 then
                                            --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                                            p_horamov := fug_obt_hor_disponible(v_fcproce,p_horamov,user,v_es_nocturno);
                                            v_max_sec_use_fgdiari := 0 ;
                                        end if;
                                        --
                                        p_lugar := 'EN Proc : LP_INS_MOV_SUELDO llama al pack: PAG_CTA.PR_ACT_OPERACION : DB Iva';
                                        p_horamov := TO_CHAR(SYSDATE,'HH24:MI:SS');
                                        if p_cierre = 'N' then
                                            pag_sue.pr_ins_log(v_ctadbsu,v_iva,'LP_INS_MOV_SUELDO',p_lugar||' Cobro de comisión al ente');
                                        end if;

                                        pag_cta.pr_set_variables(user, v_fcproce, v_tranpdb,
                                                                 'N', 'N', v_max_sec_use_fgdiari, NULL,
                                                                 v_cdofior, v_cdmodup, v_cdmodap);


                                        PAG_CTA.PR_ACT_OPERACION(v_ctadbsu,
                                                                 p_horamov,
                                                                 'D',
                                                                 v_cdmoned,
                                                                 v_iva,
                                                                 v_cdtriva,--v_tranpdb,
                                                                 v_cdtriva,
                                                                 nvl(v_remito,v_nro_documento), --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                                 NULL,
                                                                 nvl(v_cdofior,p_cdofici),
                                                                 v_cdmodup,
                                                                 v_cdmodap,
                                                                 v_cdtasas_iva,
                                                                 v_valor_iva,
                                                                 v_cnmovim,
                                                                 'S',
                                                                 v_max_sec_use_fgdiari,
                                                                 v_fcproce);

                                        v_mensaje_error := pag_cta.fu_obt_msj_error;
                                        v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                                        v_codigo_error  := pag_cta.fu_obt_cod_error;
                                        --actualiza ge_movimientos por cada fila con el nro de lote correspondiente
                                        UPDATE GE_MOVIMIENTOS
                                        SET nro_documento2 = v_nro_lote
                                        WHERE nro_cuenta = v_ctadbsu
                                          and hora = p_horamov
                                          and cod_tra_padre = v_tranpdb
                                          and nro_documento3 = p_cod_ente
                                          and cod_mod_padre = v_cdmodup
                                          and cod_mad_padre = v_cdmodap
                                          and fecha = v_fcproce;

                                        if v_proceso_ok!='S' then
                                            RAISE_APPLICATION_ERROR(-20600,'Error en pr_act_operacion : IVA '||v_codigo_error||v_mensaje_error);
                                            /*else
               update ge_movimientos
                  set nro_documento3 = p_cod_ente
                where hora = p_horamov
                   --and cod_usuario = user
                  and usu_insercion = user
                  and cod_tra_padre = v_tranpdb
                  and cod_transaccion = v_cdtriva
                  and nro_cuenta = v_ctadbsu; */
                                        end if;
                                    End if;
                                    --
                                ELSIF  NVL(v_SlDisp,0) < NVL(v_comision,0) + NVL(v_iva,0) AND
                                       NVL(v_comision,0) + NVL(v_iva,0) > 0  THEN
                                    --
                                    -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                                    if v_max_sec_use_fgdiari > 990 then
                                        v_max_sec_use_fgdiari := -999;
                                    elsif v_max_sec_use_fgdiari < 0 and v_max_sec_use_fgdiari > -10 then
                                        --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                                        p_horamov := fug_obt_hor_disponible(v_fcproce,p_horamov,user,v_es_nocturno);
                                        v_max_sec_use_fgdiari := 0 ;
                                    end if;
                                    --
                                    p_lugar                 := ' Carga registro rg_movs ';
                                    rg_movs.COD_USUARIO     := p_usuario;
                                    rg_movs.hora            := p_horamov;
                                    rg_movs.nro_secuencia   := v_max_sec_use_fgdiari + 1;
                                    rg_movs.cod_modulo      := v_cdmodul;
                                    rg_movs.cod_modalidad   := v_cdmodal;
                                    rg_movs.cod_oficina     := v_cdofici;
                                    rg_movs.nro_cuenta      := v_ctadbsu;
                                    rg_movs.cod_moneda      := v_cdmoned;
                                    rg_movs.cod_tra_padre   := v_tranpdb;
                                    rg_movs.cod_transaccion := v_cdtrcom;
                                    rg_movs.fecha           := p_fec_hoy ;
                                    rg_movs.fec_valor       := p_fec_hoy ;
                                    rg_movs.nro_documento   := nvl(v_remito,v_nro_documento); --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                    rg_movs.nro_documento3  := p_cod_ente;
                                    rg_movs.monto           := v_comision;
                                    rg_movs.est_cuenta      := 'N';
                                    rg_movs.estado          := 'E';
                                    rg_movs.cod_ofi_origen  := nvl(v_cdofior,p_cdofici);
                                    rg_movs.concepto        := v_cnmovim;
                                    rg_movs.reversado       := 'N';
                                    rg_movs.emi_aviso       := 'N';
                                    rg_movs.cod_mod_padre   := v_cdmodup;
                                    rg_movs.cod_mad_padre   := v_cdmodap;

                                    p_lugar := 'EN Proc : LP_INS_MOV_SUELDO llama al pack :PAG_GEN.PR_INS_GE_MOVIMIENTO , inserta mov E ';
                                    -- 13/12/2010 OMM Para pagar en sistema cerrado
                                    PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,v_es_nocturno);
                                END IF;
                            END IF;
                        END IF;
                        ---
                    else
                        --- agregado para RRHH
                        --------------------------------------
                        --- si no se debita de cuenta de ahorro
                        --- se debe debitar del rubro contable
                        p_lugar := 'EN Proc : LP_INS_MOV_SUELDO llama al proc. lp_obt_monto_proc ';
                        PAG_SUE.LP_OBT_MONTO_PROC(v_Secuencia, p_cod_ente, v_CantCred, v_Total_Credito,P_lugar,p_fec_hoy);

                        begin
                            select c.cod_moneda
                            into   v_cdmoned
                            from   cb_rubros c
                            where  c.cod_rubro = v_nro_cta_contable_txt;
                        exception
                            when no_data_found then
                                RAISE_APPLICATION_ERROR(-20600,'Rubro contable no posee moneda: '|| v_nro_cta_contable_txt);
                        end;

                        -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                        if v_max_sec_use_fgdiari > 990 then
                            v_max_sec_use_fgdiari := -999;
                        elsif v_max_sec_use_fgdiari < 0 and v_max_sec_use_fgdiari > -10 then
                            --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                            p_horamov := fug_obt_hor_disponible(v_fcproce,p_horamov,user,v_es_nocturno);
                            v_max_sec_use_fgdiari := 0 ;
                        end if;
                        --
                        p_lugar                 := ' Carga registro rg_movs ';
                        rg_movs.cod_transaccion := 1499;
                        rg_movs.cod_modulo      := 14;
                        rg_movs.cod_modalidad   := 141;
                        rg_movs.cod_tra_padre   := v_tranpdb;
                        rg_movs.cod_mod_padre   := 14;
                        rg_movs.cod_mad_padre   := 141;
                        rg_movs.monto           := v_Total_Credito;
                        rg_movs.cod_moneda      := v_cdmoned;
                        --
                        rg_movs.nro_cuenta      := null; --v_ctadbsu;
                        rg_movs.cod_oficina     := v_cdofici;
                        rg_movs.COD_USUARIO     := p_usuario;
                        rg_movs.hora            := p_horamov;
                        rg_movs.fecha           := pag_cal.FU_OBT_FEC_ACTUAL(1);
                        rg_movs.nro_secuencia   := v_max_sec_use_fgdiari + 1;
                        rg_movs.fec_valor       := pag_cal.FU_OBT_FEC_ACTUAL(1);
                        rg_movs.nro_documento   := nvl(v_remito,v_nro_documento); --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                        rg_movs.nro_documento3  := p_cod_ente;
                        rg_movs.cod_tasa        := null;
                        rg_movs.val_tasa        := null;
                        rg_movs.cotizacion      := null;
                        rg_movs.emi_aviso       := 'N';
                        rg_movs.cod_ofi_origen  := nvl(v_cdofior,p_cdofici);
                        rg_movs.concepto        := v_cnmovim;
                        rg_movs.estado          := 'N';
                        rg_movs.est_cuenta      := 'N';
                        rg_movs.reversado       := 'N';
                        rg_movs.emi_aviso       := 'N';
                        --
                        rg_movs.nro_caja        := null;--to_number(p_nro_caja);
                        rg_movs.cod_rubro       := v_nro_cta_contable_txt;
                        rg_movs.tip_mov_rubro   := 'D'; -- débito
                        --
                        p_lugar := 'EN Proc : LP_INS_MOV_SUELDO llama al pack :PAG_GEN.PR_INS_GE_MOVIMIENTO , inserta mov E ';
                        -- 13/12/2010 OMM Para pagar en sistema cerrado
                        PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,v_es_nocturno);

                    END IF; --- filtro agregado para RRHH

                END IF;
            end if;
            --- Actualizar como procesados los registros
            IF nvl(p_hubo_error,'N') = 'N' THEN
                UPDATE GE_PAG_SUELDOS
                SET PROCESADO = 'S'
                WHERE cod_ente = p_cod_ente
                  and fec_proceso = p_fec_hoy
                  and nro_secuencia = p_nro_secuencia
                  and nvl(cod_proceso,0) = 0;

            ELSIF P_HUBO_ERROR = 'Z' then
                p_lugar:= 'No se encontraron cuentas de Crédito. ';
            END IF;
            begin
                select sum(monto)
                into v_mto_debito
                from ge_pag_sueldos
                where cod_ente = p_cod_ente
                  and fec_proceso = P_FEC_HOY
                  and nro_secuencia = p_nro_secuencia
                  and tipo = 'D';
            exception
                when no_data_found then
                    P_HUBO_ERROR:= 'Z';
            end;

            IF v_mto_credito > 0 then
                UPDATE ge_pag_sue_lotes
                SET mto_debito = v_mto_credito,
                    mto_credito = v_mto_credito
                WHERE cod_ente = P_COD_ENTE
                  AND fec_proceso = P_FEC_HOY
                  AND nro_secuencia = P_NRO_SECUENCIA
                  AND estado = 'P';

                --Actualizar el registro de débito
                if v_pro_con_errores = 'N' then
                    update ge_pag_sueldos
                    set monto = v_mto_credito
                    where cod_ente = p_cod_ente
                      and fec_proceso = P_FEC_HOY
                      and nro_secuencia = p_nro_secuencia
                      and tipo = 'D';
                end if;
            END IF;
            --- Limpiar el seteo del nro_documento3
            pag_cta.PR_SET_NRO_DOCUMENTO3(null);

            p_sec_sgt_movimiento := rg_movs.nro_secuencia;
        END;
    end lp_ins_mov_sueldo;
/* Borra los datos procesados del temporal */
    PROCEDURE LP_DEL_DATOS_TEMPORA
    (P_COD_ENTE IN NUMBER
    ,P_FEC_HOY IN DATE
    ,P_LUGAR IN OUT VARCHAR2
    ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
    ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
    )
        IS
        v_usuario             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);
    begin
        p_lugar := 'Borra Cuentas de Empresas Procesadas ';
        v_usuario := P_COD_USUARIO;
        if v_usuario in ('HBANK', 'BBVAAPIUSR') then
            v_usuario := 'HBANK'; --Solo se cambia con digitales ya que el registro se da desde hbank
        end if;
        -- OMM 06/12/2010 -- AP 1095 Ref. AT: E
        IF v_form = 'N' THEN
            if P_NRO_ARCHIVO is null then
                DELETE GE_PAG_SUELDOS_TMP
                WHERE COD_ENTE    = p_cod_ente
                  and usu_insercion = v_usuario
                  and trunc(NVL(fec_proceso, fec_insercion)) = trunc(p_fec_hoy);
                --       and nro_archivo is null)
                --  or (trunc(fec_insercion) < trunc(sysdate)))
                --AND (FEC_PROCESO = p_fec_hoy or FEC_PROCESO IS NULL);
            else
                DELETE GE_PAG_SUELDOS_TMP
                WHERE COD_ENTE    = p_cod_ente
                  and usu_insercion = v_usuario
                  and trunc(NVL(fec_proceso,fec_insercion)) = trunc(p_fec_hoy)
                  and nro_archivo = P_NRO_ARCHIVO;
            end if ;
        ELSE
            if P_NRO_ARCHIVO is null then
                DELETE GE_PAG_SUELDOS_TMP
                WHERE COD_ENTE    = p_cod_ente
                  and usu_insercion = v_usuario
                  and trunc(fec_proceso) = trunc(p_fec_hoy);
            else
                DELETE GE_PAG_SUELDOS_TMP
                WHERE COD_ENTE    = p_cod_ente
                  and usu_insercion = v_usuario
                  and (trunc(fec_proceso) = trunc(p_fec_hoy) or fec_proceso is null)--Se agrega para elimar del temporal para Cta. Débito Inexistente.
                  and nro_archivo = P_NRO_ARCHIVO;
            end if ;
        END IF;

    exception
        When others then
            if sqlcode != -00060 THEN  --'Interbloqueo'
                --CAMBIOS ANA 20/06/2025
                p_lugar := substr('LP_DEL_DATOS_TEMPORA - error al borrar de GE_PAG_SUELDOS_TMP '||sqlerrm|| fu_obt_ubicacion,1,200);
                pag_sue.pr_ins_errores('CUENTA', p_cod_ente,trunc(p_fec_hoy),P_NRO_ARCHIVO,
                                                       null,null,'S',010,p_lugar);
                RAISE_APPLICATION_ERROR(-20010,'Al Borrar GE_PAG_SUELDOS_TMP ' || sqlerrm );
            END IF;
    end lp_del_datos_tempora;
/* Inserta en el GE_PAG_SUELDOS_TMP los registros con error */
    PROCEDURE LP_INS_ERROR_PROCESO
    (P_COD_ENTE IN NUMBER
    ,P_FEC_HOY IN DATE
    ,P_LUGAR IN OUT VARCHAR2
    ,P_NRO_SECUENCIA IN NUMBER
    ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
    ,P_FEC_INSERCION IN GE_PAG_SUELDOS.FEC_INSERCION%TYPE DEFAULT NULL
    )
        IS
        PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    begin
        p_lugar := 'Borrando Datos Temporales ';
        PAG_SUE.LP_DEL_DATOS_TEMPORA(p_cod_ente,nvl(p_fec_insercion,p_Fec_hoy),p_lugar,p_nro_secuencia,p_cod_usuario);
        ---
        p_lugar := 'Insertando errores del procesamiento...';
        INSERT INTO GE_PAG_SUELDOS_TMP
        (cod_ente, fec_proceso, nro_secuencia,
         nro_cuenta, cod_moneda, fec_envio, tipo, monto,
         estado, cod_proceso, nro_archivo)
        SELECT
            p_cod_ente, p_fec_hoy,
            nro_secuencia,  nro_cuenta, cod_moneda, fec_envio,
            tipo, monto, estado, cod_proceso, nro_secuencia
        FROM GE_PAG_SUELDOS
        WHERE cod_ente  = p_cod_ente
          and fec_proceso = p_fec_hoy
          and nro_secuencia = p_nro_secuencia
          and nvl(procesado,'N') = 'N';
        ---  AND COD_PROCESO = 0;
        commit;

    exception
        When others then
            if sqlcode <= -20000 then
                raise;
            else
                RAISE_APPLICATION_ERROR(-20020,'En '||p_lugar||'-'||sqlerrm);
            end if;
    end lp_ins_error_proceso;
/* Verifica creditos y debitos procesados */
    PROCEDURE PR_ACT_DATOS_PAGADOS
    (P_COD_ENTE IN NUMBER
    ,P_FEC_HOY IN DATE
    ,P_LUGAR IN OUT VARCHAR2
    )
        IS
    begin
        DECLARE
            v_nrsecue     NUMBER;
            v_TCRSINPROCE NUMBER(18,2);
            v_TDBSINPROCE NUMBER(18,2);
        BEGIN
            p_lugar := 'Obtiener Maxima Secuencia sin Procesar en el dia';
            BEGIN
                SELECT MAX(NRO_SECUENCIA)
                INTO v_nrsecue
                FROM GE_PAG_SUELDOS
                WHERE COD_ENTE = p_cod_ente
                  AND FEC_PROCESO = p_fec_hoy
                  AND COD_PROCESO <> 0;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_nrsecue := NULL;
                WHEN OTHERS THEN
                    RAISE_APPLICATION_ERROR(-20100,'Al obtener secuencia sin procesar '||sqlerrm);
            END;
            --
            IF v_nrsecue IS NOT NULL THEN
                p_lugar := 'Suma Total de Creditos sin procesar ';
                SELECT SUM(NVL(MONTO,0))
                INTO v_tcrsinproce
                FROM GE_PAG_SUELDOS
                WHERE COD_ENTE = p_cod_ente
                  AND FEC_PROCESO = p_fec_hoy
                  AND COD_PROCESO <> 0
                  AND tipo = 'C'
                  AND nro_secuencia = v_nrsecue;
                --
                p_lugar := 'Suma Total de Débitos sin procesar ';
                SELECT SUM(NVL(MONTO,0))
                INTO v_tdbsinproce
                FROM GE_PAG_SUELDOS
                WHERE COD_ENTE = p_cod_ente
                  AND FEC_PROCESO = p_fec_hoy
                  AND COD_PROCESO <> 0
                  AND TIPO = 'D'
                  AND nro_secuencia = v_nrsecue;
            END IF;
            --
            IF v_nrsecue IS NULL THEN
                RAISE_APPLICATION_ERROR(-20150,'No Existen Datos Cargados el día '||TO_CHAR(p_fec_hoy,'DD/MM/YYYY')||sqlerrm);
            ELSIF v_TCRSINPROCE < v_TDBSINPROCE THEN
                RAISE_APPLICATION_ERROR(-20200,'Existen Sueldos ya acreditados para la Empresa '
                    ||TO_CHAR(p_cod_ente)||'. Imposible actualizar datos !!!' ||sqlerrm);
            ELSIF v_TDBSINPROCE = 0 THEN
                RAISE_APPLICATION_ERROR(-20250,'El Débito a la Empresa '
                    ||TO_CHAR(p_cod_ente)||' fue realizado. Imposible actualizar datos !!!'||sqlerrm);
            END IF;
            --
            -- Borra los datos...
            --
            DELETE GE_PAG_SUELDOS
            WHERE COD_ENTE = p_cod_ente
              AND FEC_PROCESO = p_fec_hoy
              AND nro_secuencia = v_nrsecue;
        END;

    end pr_act_datos_pagados;
---
    PROCEDURE PR_VER_CTA_AGUINALDO
    (P_COD_ENTE IN NUMBER
    ,P_FEC_HOY IN DATE
    ,P_LUGAR IN OUT VARCHAR2
    ,P_COD_ERROR IN OUT VARCHAR2
    ,P_CTA_OK IN OUT VARCHAR2
    ,P_NRO_CUENTA IN VARCHAR2
    ,P_NRO_ARCHIVO IN VARCHAR2
    ,P_PRO_CON_ERRORES IN VARCHAR2
    ,P_MONTO IN NUMBER
    ,P_MONEDA IN VARCHAR2
    ,P_CTA_AHORRO IN OUT VARCHAR2
    ,P_TIPO IN VARCHAR2
    ,P_CTA_AGUINALDO IN OUT VARCHAR2
    )
        IS
    begin
        DECLARE
            v_nrsecue     NUMBER;
            v_TCRSINPROCE NUMBER(18,2);
            v_TDBSINPROCE NUMBER(18,2);
            v_tra_aguinaldo varchar2(1) := fug_obt_parentes(p_cod_ente, 'PAG_TRA_AGUINALDO');
            v_exi_error varchar2(1);


        BEGIN
            p_lugar := 'Verificar Cuentas de Aguinaldo';
            P_CTA_OK :='S';
            P_CTA_AGUINALDO := 'N';
            If  v_tra_aguinaldo  = 'S'  then
                --Obtener la cuenta de Caja de Ahorro para Aguinaldo
                begin
                    Select v.nro_cuenta, 'S'
                    into P_CTA_AHORRO, P_CTA_AGUINALDO
                    from ah_cta_vistas v, ge_cta_clientes ca
                    where v.nro_cuenta = p_nro_cuenta
                      and ca.nro_cuenta = v.nro_cuenta
                      and ca.relacion = 'P'
                      and v.estado not in ('C','P');
                exception
                    when no_data_found then
                        Begin
                            Select v.nro_cuenta into P_CTA_AHORRO
                            from ah_cta_vistas v, ge_cta_clientes ca,
                                 ge_Cta_clientes cl, cc_cta_corrientes cc
                            where cc.nro_cuenta = p_nro_cuenta
                              and cl.nro_cuenta = cc.nro_cuenta
                              and cl.relacion = 'P'
                              and ca.nro_cuenta = v.nro_cuenta
                              and ca.relacion = 'P'
                              and ca.cod_persona = cl.cod_persona
                              and v.estado not in ('C','P');
                        Exception
                            when no_Data_Found then
                                -- Ver si no es con caja de ahorro
                                Begin
                                    Select v.nro_cuenta into P_CTA_AHORRO
                                    from ah_cta_vistas v, ge_cta_clientes ca,
                                         ge_Cta_clientes cl, ah_cta_vistas cc
                                    where cc.nro_cuenta = p_nro_cuenta
                                      and cl.nro_cuenta = cc.nro_cuenta
                                      and cl.relacion = 'P'
                                      and v.nro_cuenta <> p_nro_cuenta
                                      and ca.nro_cuenta = v.nro_cuenta
                                      and ca.relacion = 'P'
                                      and ca.cod_persona = cl.cod_persona
                                      and v.estado not in ('C','P');
                                Exception
                                    when no_Data_Found then
                                        lp_act_ge_pag_sueldos(p_cod_ente,P_FEC_HOY, p_nro_archivo, p_nro_cuenta, 70);

                                        dbms_output.put_line('v_cuenta: '||p_nro_cuenta||' Aguinaldo');

                                        p_lugar:= 'No se encuentra la Cta. de Aguinaldo. Nro.Cta. '||P_NRO_CUENTA||' Nro. Archivo '||p_nro_archivo;
                                        P_COD_ERROR:= 70;

                                        pag_sue.pr_ins_errores(p_nro_cuenta, p_cod_ente,trunc(p_fec_hoy),p_nro_archivo,
                                                               p_moneda,p_monto,p_tipo,p_cod_error,p_lugar);
                                        P_CTA_OK:= 'N';
                                    when too_many_rows then
                                        lp_act_ge_pag_sueldos(p_cod_ente,p_Fec_hoy, P_NRO_ARCHIVO, p_nro_cuenta, 71);
                                        p_lugar:= p_lugar|| 'Se encontró más de una Cta. de Aguinaldo. Nro.Cta. '||p_nro_cuenta;
                                        P_COD_ERROR:= 71;
                                        pag_sue.pr_ins_errores(p_nro_cuenta, p_cod_ente,trunc(p_fec_hoy),p_nro_archivo,
                                                               p_moneda,p_monto,p_tipo,p_cod_error,p_lugar);

                                        P_CTA_OK:= 'N';
                                end;
                            when too_many_rows then
                                lp_act_ge_pag_sueldos(p_cod_ente,p_fec_hoy, p_nro_archivo, p_nro_cuenta, 71);
                                p_lugar:= p_lugar|| 'Se encontró más de una Cta. de Aguinaldo. Nro.Cta. '||p_nro_cuenta;
                                P_COD_ERROR:= 71;
                                pag_sue.pr_ins_errores(p_nro_cuenta, p_cod_ente,trunc(p_fec_hoy),p_nro_archivo,
                                                       p_moneda,p_monto,p_tipo,p_cod_error,p_lugar);
                                P_CTA_OK:= 'N';
                        end;
                end;
            End if;
        END;
    END;
---
/* Proceso principal de inserción y generación */
    PROCEDURE PR_INS_GE_PAG_SUELDO
    (P_VERIFICA_OK IN OUT VARCHAR2
    ,P_COD_ENTE IN NUMBER
    ,P_CTADBSU IN VARCHAR2
    ,P_TRANPDB IN NUMBER
    ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
    ,P_LUGAR IN OUT VARCHAR2
    ,P_CANT_ERROR OUT NUMBER
    ,P_TCRECAB OUT NUMBER
    ,P_TCREDET OUT NUMBER
    ,P_TDEBDET OUT NUMBER
    ,P_CCREDET OUT NUMBER
    ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
    ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
    ,P_FEC_PROCESO IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE DEFAULT NULL
    ,P_TIP_PAGO IN VARCHAR2 DEFAULT NULL
    )
        IS
    begin
        declare
            /* Definición de Variables */
            v_Tot_Debito  number(18,2) := 0;
            v_Tot_Credito number(18,2) := 0;
            v_min_fec     date;
            v_max_fec     date;
            v_cantreg     number(5) := 0;
            v_exi_error   varchar2(1);
            v_nro_lote    NUMBER(15);
            -------------------
            v_fech_env          date;
            v_fecha_insercion   date := p_fec_hoy;

            v_linea             varchar2(1000);
            v_linea_cab         varchar2(1000);
            v_cuenta            varchar2(15);
            v_tip_movimiento    varchar2(01);
            v_mensaje_error     varchar2(1000);
            v_cod_moneda        varchar2(03);
            v_cod_mon_debito    varchar2(03);
            v_est_movimiento    varchar2(01);
            v_estado_nuevo      varchar2(01);
            v_puede_procesar    varchar2(01);
            IdCta               varchar2(02);
            v_tas_personalizada varchar2(01);
            v_cod_modulo        number(03);
            v_cod_modalidad     number(03);
            v_estado            ge_cuentas.estado%type;
            v_cod_oficina       number(03);
            v_empresa           number(03);
            v_Sueldo            number(18,2);
            v_sldisponible      number(18,2);
            v_cCreCab           number(06);
            v_Secuencia         number(03);
            v_Codigo_Error      number(03);
            v_Long_Cabecera     number(04);
            v_boton             number(02);
            v_cant_linea        number(05);
--* para verificar si cta de txt es la del ente seleccionado
            v_descripcion_txt   ge_entes.descripcion%type;
            v_cta_debito_txt    ge_pag_sueldos.nro_cuenta%type;
            v_tranpdb_txt       ge_transacciones.cod_transaccion%type;
            v_tasa_txt          ge_tasas.cod_tasa%type;
            v_traniva_txt       ge_transacciones.cod_transaccion%type;
            v_lugar_txt         varchar2(200);
            v_precio_fijo       ge_par_entes.val_parametro%type;
-- Control de saldo al debitar comision + iva
            v_cdtasas                 ge_par_entes.val_parametro%type;
            v_valor_com               NUMBER(18,2);
            v_valor_iva               NUMBER(18,2);
            v_cdtriva                 ge_transacciones.cod_transaccion%type;
            v_cdtrcom                 ge_transacciones.cod_transaccion%type;
            v_Comision                NUMBER(18,2);
            v_Iva                     NUMBER(18,2);
            v_cdtasas_iva             ge_par_entes.val_parametro%type;
            v_cod_mon_local           ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;


            v_trancom_txt               ge_par_entes.val_parametro%type;
            v_tranexc_txt               ge_par_entes.val_parametro%type;
            v_tranpagui_txt             ge_par_entes.val_parametro%type;
            v_tranpcom_txt              ge_par_entes.val_parametro%type;
            v_tranpcre_txt              ge_par_entes.val_parametro%type;
            v_tranpgra_txt              ge_par_entes.val_parametro%type;---agr.p/pag.grat.
            v_deb_exceso_txt            ge_par_entes.val_parametro%type;
            v_fec_inicio_txt            ge_par_entes.val_parametro%type;
            v_fec_vencimiento_txt       ge_par_entes.val_parametro%type;
            v_ser_activo_txt            ge_par_entes.val_parametro%type;
            v_nro_cta_contable_txt      ge_par_entes.val_parametro%type; --agregado para RRHH
            v_can_max_trans_txt         ge_par_entes.val_parametro%type;
            v_referencia_txt_txt        ge_par_entes.val_parametro%type;
            v_cta_ahorro                ah_cta_vistas.nro_cuenta%type;
            v_cta_aguinaldo             varchar2(1);

            v_cta_ok            varchar2(1) := 'N';
            v_cta_deb_txt       varchar2(15);
            v_errores_ctas      varchar2(4000) := null;
            v_errores_ctas_2    varchar2(4000) := null;
            v_errores_ctas_3    varchar2(4000) := null;
            v_errores_ctas_4    varchar2(4000) := null;
            v_cantreg_err       number;
            v_con_error         number;
            v_cont              number := 0;

            v_pro_con_errores   varchar2(1) := UPPER(NVL(fug_obt_parentes(P_COD_ENTE,'PRO_CON_ERRORES'),'N'));
            v_tra_aguinaldo varchar2(2):=fug_obt_parentes(P_COD_ENTE,'PAG_TRA_AGUINALDO');

            v_nro_documento ba_personas.nom_completo%type;
            v_usuario             ba_usuarios.cod_usuario%TYPE := substr(user,  1, 10);

            cursor c1 is Select *
                         from GE_PAG_SUELDOS_TMP
                         where cod_ente  = p_cod_ente
                           and usu_insercion = p_cod_usuario
                           and trunc(nvl(fec_insercion,fec_proceso)) = trunc(nvl(v_fecha_insercion,p_fec_proceso))
                           and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
                         Order by decode(TIPO, 'D', 1, 99)
                             for update of estado;

        BEGIN
            v_secuencia := nvl(v_secuencia,0) + 1;
            p_TCreDet := 0;
            p_TDebDet := 0;
            p_cCreDet := 0;
            p_verifica_ok := 'S';
            v_cantreg_err:= 0;
            v_precio_fijo := fug_obt_parentes(p_cod_ente, 'COD_TRA_PRECIO_FIJO');

            -- OMM 30/09/2014. Si es Aguinaldo no debe procesar con errores.
            if nvl(P_TIP_PAGO,'S') = 'A' then
                v_pro_con_errores := 'C';
            end if ;
            --------------------------------------------------------------------------------
            p_lugar := 'PR_INS_GE_PAG_SUELDO : ';
            if nvl(PAE_CNF.G_PROGRAMA,'x')= 'GPPAGSUE' then
                v_form := 'S'; --Se ejecuta desde el form
            end if;
            -- Indica si viene del Form o del proceso en Batch
            IF v_form != 'N' THEN
                v_fecha_insercion := SYSDATE;
            END IF;
            -----------------------------


            BEGIN
                begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

                -- Se verifican los datos leidos....
                Select sum(decode(tipo, 'D', monto, 0)) Tot_debito,
                       sum(decode(tipo, 'C', monto, 0)) Tot_credito,
                       min(fec_envio), max(fec_envio), count(*)
                into v_Tot_debito, v_Tot_credito, v_min_fec, v_max_fec, v_cantreg
                from GE_PAG_SUELDOS_TMP
                where cod_ente = p_cod_ente
                  AND usu_insercion = p_cod_usuario
                  and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
                  and trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(v_fecha_insercion,p_fec_proceso));


                Select count(*)
                into v_cantreg_err
                from GE_PAG_SUELDOS_TMP
                where cod_ente = p_cod_ente
                  AND usu_insercion = p_cod_usuario
                  and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
                  and trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(v_fecha_insercion,p_fec_proceso))
                  and nvl(cod_proceso,0) <> 0;
                ---
                --- modificado para RRHH
                /*if v_cantreg = 0 then
            RAISE_APPLICATION_ERROR(-20700,'Archivo sin dato ');
         else
             if nvl(v_Tot_Debito,0) != nvl(v_Tot_Credito,0) Then
              RAISE_APPLICATION_ERROR(-20710,'Total de Créditos no coincide con Total de Débitos');
             else
                v_fech_env := v_min_fec;
                p_TCreCab  := v_tot_Credito;
            end if;
         end if;
         ---
      p_lugar := 'proc: PR_INS_GE_PAG_SUELDO : Obt_Datos_cuenta';
      pag_sue.lp_obt_datos_cuenta(p_ctadbsu,v_tas_personalizada,v_cod_mon_debito,p_lugar);
      --*/


                PAG_SUE.PR_OBT_DATOS_EMPRESA(p_cod_ente,
                                             v_descripcion_txt,
                                             v_cta_debito_txt,
                                             v_tranpdb_txt,
                                             v_trancom_txt,   ---v_tasa_txt,
                                             v_tranexc_txt,   ---v_traniva_txt,
                                             v_tranpagui_txt, ---v_trancom_txt,
                                             v_tranpcom_txt,
                                             v_tranpcre_txt,
                                             v_tranpgra_txt,  ---agr.p/pag.grat.
                                             v_deb_exceso_txt,
                                             v_fec_inicio_txt,
                                             v_fec_vencimiento_txt,
                                             v_ser_activo_txt,
                                             v_can_max_trans_txt,
                                             v_nro_cta_contable_txt, ---Agregado para RRHH
                                             v_referencia_txt_txt,
                                             v_lugar_txt,
                                             v_fecha_insercion,
                                             p_cod_usuario);

                --- agregado para RRHH
                if v_nro_cta_contable_txt is not null then
                    --v_cod_mon_debito := fuy_obt_mon_base;
                    -- RI : 23/02/2010 : busco la moneda del rubro
                    v_cod_mon_debito := fu_obt_mon_rubro(v_nro_cta_contable_txt);
                elsif v_cta_debito_txt is not null then
                    if (nvl(v_Tot_Debito,0) != nvl(v_Tot_Credito,0) and v_pro_con_errores = 'C') Then
                        --CAMBIOS ANA 20/06/2025
                        p_lugar := substr('PR_INS_GE_PAG_SUELDO - verifica total de debito contra credito '|| fu_obt_ubicacion,1,200);
                        pag_sue.pr_ins_errores(p_ctadbsu, p_cod_ente,trunc(p_fec_hoy),p_nro_archivo,
                                                       null,null,p_tip_pago,710,p_lugar);
                        RAISE_APPLICATION_ERROR(-20710,'Total de Creditos no coincide con Total de Debitos');
                    else
                        p_lugar := 'proc: PR_INS_GE_PAG_SUELDO : Obt_Datos_cuenta';
                        pag_sue.lp_obt_datos_cuenta(p_ctadbsu,v_tas_personalizada,v_cod_mon_debito,p_lugar);
                    end if;
                else
                    --CAMBIOS ANA 20/06/2025
                    p_lugar := substr('PR_INS_GE_PAG_SUELDO - falta parametrizar rubro contable '|| fu_obt_ubicacion,1,200);
                    pag_sue.pr_ins_errores(p_ctadbsu, p_cod_ente,trunc(p_fec_hoy),p_nro_archivo,
                                                    null,null,p_tip_pago,720,p_lugar);
                    RAISE_APPLICATION_ERROR(-20720,'Se debe parametrizar para que el descuento se realice
                                             del Rubro Contable o de la Cta. de Débito');
                end if;

                ------------------------
                v_fech_env := v_min_fec;
                p_TCreCab  := v_tot_Credito;
                -----------------------
                Update ge_pag_sueldos_tmp
                set nro_secuencia = v_secuencia,
                    fec_proceso   = trunc(NVL(p_fec_proceso,v_fecha_insercion))
                where cod_ente = p_cod_ente
                  AND usu_insercion = p_cod_usuario
                  and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
                  and trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(v_fecha_insercion,p_fec_proceso));

                --and fec_proceso = p_fec_hoy;

                v_cta_ok := 'S';
                FOR r1 in c1 LOOP
                        v_cta_ok := 'S';
                        --BEGIN
                        v_tip_movimiento := r1.tipo;
                        v_codigo_error   := NULL;
                        IF v_tip_movimiento = 'D' then
                            if v_nro_cta_contable_txt  is null THEN
                                v_cta_deb_txt := r1.nro_cuenta;
                                -- Se comenta el control de la cuenta debito contra el parametro
                                -- porque no se tiene esa informacion de la migracion de datos
                                --lp_ver_cuenta_Debito(p_cod_ente,r1.nro_cuenta,v_cta_ok);
                                --if r1.nro_cuenta <> v_cta_debito_txt then
                                -- v_cta_ok := 'N';
                                --end if;
                                v_cuenta := p_ctadbsu;
                                v_Sueldo := v_Tot_Debito;
                            else
                                v_cta_deb_txt := null;
                                v_cuenta := null;
                                v_sueldo := v_tot_debito;
                                p_TDebDet := v_tot_debito;
                            end if;
                        ELSE
                            v_cuenta  := r1.nro_cuenta;
                            v_sueldo  := r1.monto;
                        END IF;

                        if v_cta_ok = 'N' and v_tip_movimiento = 'D' then
                            v_codigo_error := 48;
/*            Update ge_pag_sueldos_tmp
               set cod_proceso   = 48
             where nro_cuenta = v_cta_deb_txt
               and fec_proceso = p_fec_hoy
               and nro_secuencia = v_secuencia;*/
                        end if;

                        If  v_cuenta is not null then
                            --Obtengo el modulo,la modalidad y la oficina de la cuenta
                            BEGIN
                                SELECT A.COD_MODULO,A.COD_MODALIDAD,A.COD_OFICINA,A.COD_MONEDA,a.estado
                                INTO v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_estado
                                FROM GE_CUENTAS A
                                WHERE A.NRO_CUENTA = V_CUENTA;
                                --- si es cta ahorro o cta cte
                                if v_cod_modalidad not in (31,41,334) THEN
                                    --'MODALIDAD DE LA CUENTA INVALIDO';
                                    v_codigo_error := 52;
                                    v_cta_ok := 'N';
                                end if;
                                if v_estado is null then
                                    --'ESTADO INVALIDO';
                                    v_codigo_error := 53;
                                    v_cta_ok := 'N';
                                end if;
                                if v_estado IN ('C','T','P','X') and nvl(v_sueldo,0) > 0 THEN
                                    /*--'ESTADO DE LA CUENTA INVALIDO';
                  C-CANCELADA
                  T-BLOQUEO TOTAL
                  P-CERRADA
                  X-VERIFICACION*/
                                    --v_codigo_error := 55;
                                    /*
                  || rabf 10/02/2011 - despliega en el error
                  || la descripción del estado de la cuenta
                  */
                                    select decode(v_estado,'C',67,'T',68,'P',69,'X',70,55)
                                    into   v_codigo_error
                                    from   dual;
                                    v_cta_ok := 'N';
                                end if;

                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    v_codigo_error := 12;
                                    v_cta_ok := 'N';
                                WHEN OTHERS THEN
                                    v_codigo_error := 12;
                                    v_cta_ok := 'N';
                            END;

                            -- verificar que el nro documento pertenezca al cliente
                            v_nro_documento := r1.nro_documento;
                            if fug_obt_parentes(p_cod_ente,'VAL_NRO_DOCUMENTO') = 'S' then
                                if nvl(v_nro_documento,'0') <> fug_obt_pardinamico('NRO_DOC_GEN_PAG_SAL')
                                    and v_tip_movimiento = 'C' then
                                    if pag_sue.fu_ver_cta_documento(v_nro_documento, v_cuenta) = 'N' then
                                        v_codigo_error := 90;
                                        v_cta_ok := 'N';
                                    end if;
                                end if;
                            end if;

                            if v_cta_ok = 'S' then
                                if nvl(v_sueldo,0) > 0 then

                                    PAG_CTA.PR_VER_OPERACION(v_cuenta,
                                                             p_tranpdb,
                                                             v_cod_modulo,
                                                             v_cod_modalidad,
                                                             v_tip_movimiento,
                                                             v_cod_moneda,
                                                             v_Sueldo,
                                                             v_cod_oficina,
                                                             v_cod_modulo,
                                                             v_cod_modalidad,
                                                             v_estado_nuevo,
                                                             v_sldisponible,
                                                             v_puede_procesar);

                                    v_sldisponible := pag_cta.fu_sal_dis_combinada; --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                                    -- OMM 17/12/2013. Es Cta Cte, se verifica linea de sobregiro
                                    if v_cod_modulo = 4 then
                                        v_sldisponible := v_sldisponible + pag_cta.FU_OBT_LIN_SOBREGIRO(v_cuenta) ;
                                    end if ;
                                    if v_sldisponible < 0
                                        and v_tip_movimiento = 'C'
                                        and nvl(P_TIP_PAGO,'A') = 'A'
                                        and v_tra_aguinaldo  = 'S'  then -- Solo cuando es Traspaso = 'S'
                                        v_Codigo_Error := 73;
                                        lp_act_ge_pag_sueldos(p_cod_ente,trunc(v_fecha_insercion), p_nro_archivo, v_cuenta, 73);
                                        v_mensaje_error := 'Cuenta '||v_cuenta||' no permite crédito concepto Aguinaldo p/ el débito de GS '||v_sueldo;
                                        v_puede_procesar := 'N';
                                    else
                                        v_mensaje_error := PAG_CTA.FU_OBT_MSJ_ERROR;
                                        v_Codigo_Error := PAG_CTA.FU_OBT_COD_ERROR;
                                    end if;
                                    if v_codigo_error > 0 then
                                        p_lugar := 'PAG_CTA.PR_VER_OPERACION : '||v_cuenta;
                                        p_lugar := p_lugar || ' ('|| v_Codigo_Error || ') ' || v_mensaje_error;
                                    else
                                        --FQ Verificar la cuenta de aguinaldo
                                        if v_tip_movimiento = 'C' and P_TIP_PAGO = 'A' and v_cta_ok = 'S' THEN
                                            PAG_SUE.PR_VER_CTA_AGUINALDO(P_COD_ENTE,trunc(p_fec_proceso),v_mensaje_error,v_Codigo_Error,v_cta_ok,v_cuenta,p_nro_archivo, v_pro_con_errores,v_sueldo,v_cod_moneda,v_cta_ahorro,v_tip_movimiento,v_cta_aguinaldo);
                                        end if;
                                    end if;
                                end if;

                                if v_cta_ok = 'S' then
                                    IF v_puede_procesar = 'S' AND v_cod_mon_debito = v_cod_moneda THEN
                                        v_est_movimiento := 'N'; -- Movimiento Normal
                                    ELSIF v_puede_procesar = 'S' AND v_cod_mon_debito <> v_cod_moneda THEN
                                        v_est_movimiento := 'E'; -- Movimiento Erróneo
                                        v_Codigo_Error := 43;
                                    ELSE
                                        v_est_movimiento := 'E'; -- Movimiento Erróneo
                                    END IF;
                                    --dbms_output.put_line(v_cuenta||'v_est_movimiento: '||v_est_movimiento);
                                    if v_est_movimiento = 'E' and v_tip_movimiento = 'C' then
                                        --FQ Agrego la verificación de la cuenta para recuperar el error. BBVADES 2576
                                        p_lugar := 'PAG_CTA.PR_VER_OPERACION : '||v_cuenta;
                                        if nvl(P_TIP_PAGO,'A') <> 'A' then
                                            PAG_CTA.PR_VER_OPERACION(v_cuenta,
                                                                     p_tranpdb,
                                                                     v_cod_modulo,
                                                                     v_cod_modalidad,
                                                                     v_tip_movimiento,
                                                                     v_cod_moneda,
                                                                     v_Sueldo,
                                                                     v_cod_oficina,
                                                                     v_cod_modulo,
                                                                     v_cod_modalidad,
                                                                     v_estado_nuevo,
                                                                     v_sldisponible,
                                                                     v_puede_procesar);

                                            v_sldisponible := pag_cta.fu_sal_dis_combinada; --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>

                                            v_mensaje_error := PAG_CTA.FU_OBT_MSJ_ERROR;
                                            v_Codigo_Error := PAG_CTA.FU_OBT_COD_ERROR;
                                        else
                                            v_mensaje_error:= fug_obt_err_sueldos(v_Codigo_Error)||' Nro. Archivo '||p_nro_archivo;
                                        end if;
                                        pag_sue.pr_ins_errores(v_cuenta, p_cod_ente,trunc(p_fec_proceso),r1.nro_archivo,
                                                               v_cod_moneda,v_sueldo,v_tip_movimiento,v_Codigo_Error,v_mensaje_error);
                                    end if;

                                    if v_est_movimiento = 'N' Then
                                        if v_tip_movimiento = 'C' Then
                                            p_TCreDet := p_TCreDet + v_Sueldo;
                                            p_cCreDet := p_cCreDet + 1;
                                        else
                                            p_TDebDet := p_TDebDet + v_Sueldo;
                                        end if;
                                    End if;
                                    ---* valido si tiene saldo suficiente - 16/02/05
                                    if v_sldisponible < v_Tot_debito and v_puede_procesar = 'N' and r1.nro_cuenta = p_ctadbsu then
                                        v_Codigo_Error  :=25;
                                    end if;
                                else
                                    v_mensaje_error:= fug_obt_err_sueldos(v_Codigo_Error)||' Nro. Archivo '||p_nro_archivo;
                                End if;
                            else
                                v_puede_procesar := 'N';
                                if v_tip_movimiento = 'C' and nvl(v_Codigo_Error,0) <> 0 then
                                    --FQ Se debe insertar en la tabla de errores si el error no se ha insertado aún.
                                    --cod error 90 CI no corresponde a cuenta
                                    if P_TIP_PAGO <> 'A' and v_Codigo_Error not in (90) then
                                        PAG_CTA.PR_VER_OPERACION(v_cuenta,
                                                                 p_tranpdb,
                                                                 v_cod_modulo,
                                                                 v_cod_modalidad,
                                                                 v_tip_movimiento,
                                                                 v_cod_moneda,
                                                                 v_Sueldo,
                                                                 v_cod_oficina,
                                                                 v_cod_modulo,
                                                                 v_cod_modalidad,
                                                                 v_estado_nuevo,
                                                                 v_sldisponible,
                                                                 v_puede_procesar);

                                        v_mensaje_error := PAG_CTA.FU_OBT_MSJ_ERROR;
                                        v_Codigo_Error := PAG_CTA.FU_OBT_COD_ERROR;
                                    else
                                        v_mensaje_error:= fug_obt_err_sueldos(v_Codigo_Error)||' Nro. Archivo '||p_nro_archivo;
                                    end if;

                                    pag_sue.pr_ins_errores(v_cuenta, p_cod_ente,trunc(p_fec_proceso),r1.nro_archivo,
                                                           v_cod_moneda,v_sueldo,v_tip_movimiento,v_Codigo_Error,v_mensaje_error);

                                end if;
                            End if;
                            IF NOT v_Codigo_Error IS NULL AND v_Codigo_Error != 0 THEN
                                v_cont:= v_cont + 1;
                                if v_cont <= 45 then
                                    v_errores_ctas := v_errores_ctas || chr(10) || V_CUENTA || ' (' || v_Codigo_Error || ') ' || v_mensaje_error;
                                    v_errores_ctas := v_errores_ctas || '| Error en Cta. de crédito: '|| v_cuenta;
                                elsif v_cont between 46 and 90 THEN
                                    v_errores_ctas_2:= v_errores_ctas_2 || chr(10) || V_CUENTA || ' (' || v_Codigo_Error || ') ' || v_mensaje_error;
                                elsif v_cont between 91 and 135 then
                                    v_errores_ctas_3:= v_errores_ctas_3 || chr(10) || V_CUENTA || ' (' || v_Codigo_Error || ') ' || v_mensaje_error;
                                elsif v_cont between 136 and 170 then
                                    v_errores_ctas_4:= v_errores_ctas_4 || chr(10) || V_CUENTA || ' (' || v_Codigo_Error || ') ' || v_mensaje_error;
                                end if;
                            END IF;
                        End if;
                        ---*
                        --Verifico si tiene saldo para la comision + iva
/*        if  v_trancom_txt is not null then
           if r1.nro_cuenta = p_ctadbsu and v_puede_procesar = 'S' then
              PRG_OBT_CARGOS
              (v_cod_oficina,        --P_COD_OFI_ORIGEN     IN GE_CUENTAS.COD_OFICINA%TYPE
               v_cta_deb_txt,        --P_NRO_CUENTA         IN GE_CUENTAS.NRO_CUENTA%TYPE
               v_cod_moneda ,        --P_COD_MONEDA         IN GE_CUENTAS.COD_MONEDA%TYPE
               v_Sueldo,             --P_MONTO              IN GE_MOVIMIENTOS.MONTO%TYPE
               v_cod_modulo,         --P_COD_MODULO         IN GE_CUENTAS.COD_MODULO%TYPE
               v_cod_modalidad,      --P_COD_MODALIDAD      IN GE_CUENTAS.COD_MODALIDAD%TYPE
               v_trancom_txt,        --P_COD_TRA_CARGO      IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
               v_cdtasas,            --P_COD_TAS_CARGO      OUT GE_MOVIMIENTOS.COD_TASA%TYPE
               v_valor_com,          --P_VAL_TAS_CARGO      OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
               v_comision,           --P_VAL_CARGO          OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
               v_cdtriva,            --P_COD_TRA_IMPUESTO   OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
               v_cdtasas_iva,        --P_COD_TAS_IMPUESTO   OUT GE_MOVIMIENTOS.COD_TASA%TYPE
               v_valor_iva,          --P_VAL_TAS_IMPUESTO   OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
               v_iva );             -- P_VAL_IMPUESTO       OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
               --- si el precio es fijo, la comision deber ser igual ---
               if nvl(v_precio_fijo,'N') = 'S' then
                  v_comision := v_comision;
               else
              -- si es valor debe multiplicar por la cant. de creditos ---
              if v_valor_com = nvl(v_comision,0) + nvl(v_iva,0) then
                 v_tot_debito := (nvl(v_comision,0) + nvl(v_iva,0)) * (nvl(v_cantreg,0) - 1); --Se resta 1 a cantreg porque 1 es de deb.
                 if v_cod_moneda = v_cod_mon_local then
                     v_iva := round((v_tot_debito * nvl(v_valor_iva,0) / (nvl(v_valor_iva,0) + 100)),0);
                 else
                     v_iva := round((v_tot_debito * nvl(v_valor_iva,0) / (nvl(v_valor_iva,0) + 100)),2);
                 end if;
                 v_comision := v_tot_debito - v_iva;
              end if;
               end if;
              if v_sldisponible + nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(v_cta_deb_txt),0) < (v_Sueldo + nvl(v_iva,0) + nvl(v_comision,0)) then
                --v_Codigo_Error  := 25;
                raise_application_error(-20013,'La Cta:'||v_cta_deb_txt||
                                               ' no cubre la Comisión:'||v_comision||
                                               ' Iva:'||v_iva);
              end if;
           end if;
         end if;  */
                        --
                        Update ge_pag_sueldos_tmp
                        set estado       = v_est_movimiento,
                            cod_ente      = p_cod_ente,
                            cod_proceso   = v_codigo_error,
                            cod_modalidad = v_cod_modalidad,
                            cod_moneda    = v_cod_moneda,
                            cod_modulo    = v_cod_modulo
                        where current of c1;

                        if sql%notfound then
                            --CAMBIOS ANA 20/06/2025
                            p_lugar := substr('PR_INS_GE_PAG_SUELDO - error al actualizar ge_pag_sueldos_tmp '|| fu_obt_ubicacion,1,200);
                            pag_sue.pr_ins_errores(p_ctadbsu, p_cod_ente,trunc(p_fec_hoy),p_nro_archivo,
                                                       null,null,p_tip_pago,725,p_lugar);
                            RAISE_APPLICATION_ERROR(-20725,'ERROR. Al actualizar ge_pag_sueldos_tmp '||sqlerrm);
                        end if;
                        -- EXCEPTION
                        --  WHEN OTHERS THEN
                        --    raise_application_error(-20333,'Error '||sqlerrm);
                        -- ENd;
                    END LOOP;
                --actualiza nro de lote en ge_pag_sueldos_tmp
                begin select s_nro_lote_sue.nextval into v_nro_lote  from dual; end;--genera nro de lote
                update ge_pag_sueldos_tmp
                set nro_lote = v_nro_lote
                where cod_ente = p_cod_ente
                  and nro_secuencia= 1;
                v_cont:= 0;
                p_lugar:= v_errores_ctas;
            END;
            /* ---- RI : 07/10/09 : Se lleva este control al form, a fin de emitir una alerta
y permitir al usuario decidir si continuar o no

    p_lugar := 'Verifica_Dup_En_Mov_Diario ';
    PAG_SUE.LP_VER_DUP_MOV_DIARI(v_cuenta,v_Sueldo,p_cod_ente);
*/


            -- p_lugar :=  'PR_INS_GE_PAG_SUELDO : Verificando ERRORES';

            BEGIN
                SELECT COUNT(*)
                INTO p_Cant_Error
                FROM ge_pag_sueldos_tmp
                WHERE cod_ente = p_cod_ente
                  and usu_insercion = p_cod_usuario
                  and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
                  and trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(p_fec_proceso,v_fecha_insercion))
                  and nvl(cod_proceso,0) <> 0;
            EXCEPTION
                WHEN OTHERS THEN
                    p_Cant_Error := 0;
            END;

            --Verifico si el archivo registró algún error
            if v_pro_con_errores = 'N' then
                begin
                    select count(*)
                    into v_con_error
                    from ge_pag_sueldos_err
                    where cod_ente = p_cod_ente
                      and trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(p_fec_proceso,v_fecha_insercion))
                      and nvl(nro_secuencia, 0) = nvl(p_nro_archivo, 0);
                exception
                    when others then
                        v_con_error:= 0;
                end;
            end if;

            --Agregado para verificar si el Débito coincide con el total de créditos en caso de que no haya cuentas con error.
            if (nvl(v_Tot_Debito,0) != nvl(v_Tot_Credito,0) and v_pro_con_errores = 'C')
                or(nvl(v_Tot_Debito,0) != nvl(v_Tot_Credito,0) and v_pro_con_errores = 'N' and v_con_error = 0)Then
                --CAMBIOS ANA 20/06/2025
                p_lugar := substr('PR_INS_GE_PAG_SUELDO - verifica total de debito contra credito - 2 '|| fu_obt_ubicacion,1,200);
                pag_sue.pr_ins_errores(p_ctadbsu, p_cod_ente,trunc(p_fec_hoy),p_nro_archivo,
                                                       null,null,p_tip_pago,711,p_lugar);
                RAISE_APPLICATION_ERROR(-20711,'Total de Créditos no coincide con Total de Débitos');
            end if;

            v_usuario := P_COD_USUARIO;
            if v_usuario in ('HBANK', 'BBVAAPIUSR') then
                v_usuario := 'HBANK'; --Solo se cambia con digitales ya que el registro se da desde hbank
            end if;

            DELETE ge_pag_sueldos_tmp
            WHERE cod_ente = p_cod_ente
              AND usu_insercion = v_usuario
              AND nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
              AND trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(p_fec_proceso,v_fecha_insercion))
              AND cod_proceso <> 0;
        END;
    end pr_ins_ge_pag_sueldo;
/* Obtener los datos de la cuenta */
    PROCEDURE LP_OBT_DATOS_CUENTA
    (P_NRO_CUENTA IN VARCHAR2
    ,P_TAS_PERSONALIZADA IN OUT VARCHAR2
    ,P_COD_MONEDA IN OUT VARCHAR2
    ,P_LUGAR OUT VARCHAR2
    )
        IS
    begin
        p_lugar := 'Obteniendo Datos de la Cuenta';
        Select tas_personalizada, cod_moneda
        into p_tas_personalizada, p_cod_moneda
        from GE_CUENTAS
        where nro_cuenta = p_nro_cuenta;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('LP_OBT_DATOS_CUENTA - la cuenta no existe '|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(p_nro_cuenta, to_number(substr(p_nro_cuenta,1,5)),trunc(sysdate),999,
                                                       null,null,'S',030,p_lugar);
            RAISE_APPLICATION_ERROR(-20030,'ERROR. Cuenta :'||p_nro_cuenta||' no existe.');
        WHEN OTHERS THEN
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('LP_OBT_DATOS_CUENTA - '||p_nro_cuenta|| ' - ' || sqlerrm ||' '|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(p_nro_cuenta, to_number(substr(p_nro_cuenta,1,5)),trunc(sysdate),998,
                                                       null,null,'S',040,p_lugar);
            RAISE_APPLICATION_ERROR(-20040,'ERROR. obt. datos cuenta: '||p_nro_cuenta||' '||sqlerrm);
    end lp_obt_datos_cuenta;
/* Verifica que la cuenta de debito existe en la referencia ingresada en parametros*/
    PROCEDURE LP_VER_CUENTA_DEBITO (
        P_COD_ENTE IN NUMBER
    ,P_CTA_DEBITO IN VARCHAR2
    ,P_EXISTE OUT VARCHAR2) IS
        v_instr  number;
    BEGIN
        Select instr(val_parametro,p_Cta_debito)
        into v_instr
        from ge_par_entes
        where cod_ente =  p_cod_ente
          and parametro = 'REF_CTA_DEBITO';
        If nvl(v_instr,0) = 0 then
            P_Existe := 'N';
        else
            P_existe := 'S';
        end if;
    EXCEPTION
        when others then
            RAISE_APPLICATION_ERROR(-20030,'ERROR. Al verificar cuenta debito :'||p_cta_debito||' '||sqlerrm);
    END;
/* Verifica que ya no se hayan insertado los mov. de sueldos de la fecha */
    PROCEDURE LP_VER_DUP_MOV_DIARI
    (P_CUENTA IN VARCHAR2
    ,P_SUELDO IN NUMBER
    ,P_COD_ENTE IN NUMBER
    )
        IS

        V_HRMOVIM VARCHAR2(8);
        V_DCEMPRESA VARCHAR2(35);
        V_EMPRESA NUMBER(3);
        V_FEC_PROCESO date := pag_cal.FU_OBT_FEC_ACTUAL(1);
        v_nro_secuencia number(3);
    BEGIN
        v_HrMovim := NULL;
        v_Empresa := NULL;
        select bb.nro_secuencia into v_nro_secuencia
        from
            (select s1.cod_ente,s1.fec_proceso,s1.nro_secuencia,
                    sum(decode(s1.tipo,'D',s1.monto,0)) debito,
                    sum(decode(s1.tipo,'C',s1.monto,0)) credito,
                    count(*) cantidad
             from ge_pag_sueldos_tmp s1
             where s1.cod_ente = p_cod_ente
               and s1.usu_insercion = user
               and trunc(s1.fec_insercion) = trunc(sysdate)
             --and s1.fec_proceso = v_fec_proceso
             group by s1.cod_ente,s1.fec_proceso,s1.nro_secuencia) aa,
            (select s2.cod_ente,s2.fec_proceso,s2.nro_secuencia,
                    sum(decode(s2.tipo,'D',s2.monto,0)) debito,
                    sum(decode(s2.tipo,'C',s2.monto,0)) credito,
                    count(*) cantidad
             from ge_pag_sueldos s2
             where s2.cod_ente = p_cod_ente
               and s2.fec_proceso = v_fec_proceso
             group by s2.cod_ente,s2.fec_proceso,s2.nro_secuencia) bb
        where aa.cod_ente = bb.cod_ente
          and aa.fec_proceso = bb.fec_proceso
          and aa.debito = bb.debito
          and aa.credito = bb.credito
          and aa.cantidad = bb.cantidad;
        IF v_nro_secuencia IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20050,'Información Procesada en fecha de hoy en la SECUENCIA. '||v_nro_secuencia);
        END IF;
        --
/*  SELECT HORA  INTO v_HrMovim
    FROM GE_MOVIMIENTOS
   WHERE NRO_CUENTA = p_cuenta
     AND NRO_DOCUMENTO = p_cod_ente
     AND MONTO = p_sueldo
     and reversado = 'N';
  IF v_HrMovim IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20050,'ERROR. Información Procesada en fecha de hoy a las '||v_hrmovim);
  END IF;*/
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END;
/* Obtener la max hora para todos los movimientos */
    PROCEDURE LP_OBT_HORA_MOVIM
    (P_HORA IN OUT VARCHAR2
    ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE
    ,P_COD_TRA_PADRE IN VARCHAR2
    ,P_LUGAR OUT VARCHAR2
    )
        IS
    begin
        p_lugar := 'Obtener_Hora_Movimiento';
        SELECT MAX(hora)
        INTO p_hora
        FROM ge_movimientos
        WHERE fecha = p_Fec_hoy
          AND cod_tra_padre = p_cod_tra_padre
          and reversado = 'N' ;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20080,'Al obtener hora movimiento '||sqlerrm);
    end lp_obt_hora_movim;
/* Obtener cant.y monto total de pago de sueldo */
    PROCEDURE LP_OBT_MONTO_PROC
    (P_SECUENCIA IN NUMBER
    ,P_COD_ENTE IN NUMBER
    ,P_CANTCRED IN OUT NUMBER
    ,P_MONTCRED IN OUT NUMBER
    ,P_LUGAR OUT VARCHAR2
    ,P_FEC_HOY IN DATE
    )
        IS
    begin
        --Obtener Cantidad y Monto Total del Pago de Sueldos
        p_lugar := 'Obtener_CantMont_Proc_Total';
        SELECT count(*), SUM(NVL(MONTO,0))
        INTO p_CantCred, p_MontCred
        FROM GE_PAG_SUELDOS
        WHERE COD_ENTE = p_cod_ente
          AND TIPO = 'C'
          and fec_proceso = trunc(P_FEC_HOY)
          and nro_secuencia = p_secuencia
          and monto > 0;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20090,'Al Buscar monto y cant total proceso '||sqlerrm);
    end lp_obt_monto_proc;
/* Obtener datos de la empresa */
    PROCEDURE PR_OBT_DATOS_EMPRESA
    (P_EMPRESA         IN NUMBER
    ,P_DESCRIP         IN OUT VARCHAR2
    ,P_CTADBSU         IN OUT VARCHAR2
    ,P_TRANPDB         IN OUT NUMBER
    ,P_TRANCOM         IN OUT NUMBER
    ,P_TRANEXC         IN OUT NUMBER
    ,P_TRANPAGUI       IN OUT NUMBER
    ,P_TRANPCOM        IN OUT NUMBER
    ,P_TRANPCRE        IN OUT NUMBER
    ,P_TRANPGRA        IN OUT NUMBER  -- agregado para pago de gratificación
    ,P_DEB_EXCESO      IN OUT VARCHAR2
    ,P_FEC_INICIO      IN OUT DATE
    ,P_FEC_VENCIMIENTO IN OUT DATE
    ,P_SER_ACTIVO      IN OUT VARCHAR2
    ,P_CAN_MAX_TRANS   IN OUT NUMBER
    ,P_NRO_CTA_CONTABLE IN OUT VARCHAR2
    ,P_REFERENCIA_TXT  IN OUT VARCHAR2
    ,P_LUGAR OUT VARCHAR2
    ,P_FEC_HOY IN DATE DEFAULT SYSDATE
    ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
    )
        IS
    begin

        p_lugar := 'Obt_Datos_Empresa';
        SELECT descripcion
        INTO p_descrip
        FROM GE_ENTES
        WHERE cod_ente = p_empresa;
        ------------------------------------------
        -- Se debe obtener los demás parametros...
        ------------------------------------------
        --RI : 06/11/09 -- Se toma la cuenta de debito que viene en el archivo
        --de texto leído como cabecera, si no viene nada entonces se toma el
        -- parametro
        Begin
            Select nro_cuenta into p_ctadbsu
            from ge_pag_sueldos_tmp
            where cod_ente = p_empresa
              and trunc(nvl(fec_proceso,fec_insercion)) = trunc(p_fec_hoy)
              and usu_insercion = p_cod_usuario
              and tipo = 'D';
        Exception
            when no_Data_found then
                Begin
                    Select nro_cuenta into p_ctadbsu
                    from ge_pag_sueldos t
                    where cod_ente = p_empresa
                      and trunc(nvl(fec_proceso,fec_insercion)) = trunc(p_fec_hoy)
                      --and fec_proceso = pag_cal.fu_obt_fec_actual(3)
                      and tipo = 'D'
                      and nro_Secuencia = (select max(nro_Secuencia)
                                           from ge_pag_sueldos t2
                                           where t2.cod_ente = p_empresa
                                             and trunc(fec_insercion) = trunc(p_fec_hoy)
                                             --and t2.fec_proceso = pag_cal.fu_obt_fec_actual(3)
                                             and t2.fec_proceso = p_fec_hoy
                                             and t2.tipo = 'D');
                Exception
                    when others then
                        p_ctadbsu := null;
                end;
            when others then
                p_ctadbsu := null;
        End;
        if  p_ctadbsu is null then
            p_ctadbsu := fug_obt_parentes(p_empresa, 'NRO_CTA_DEBITO');
        end if;
        --  Comentado para funcionalidad de cuenta de ahorro o rubro contable en modulo de RRHH
--  IF p_ctadbsu IS NULL THEN
--   RAISE_APPLICATION_ERROR(-20300,'ATENCION. La empresa no posee Cuenta de Débito. Verifique!!!');
--  END IF;

        p_tranpdb := fug_obt_parentes(p_empresa, 'COD_TRA_PAD_SUELDO');
        if p_tranpdb IS NULL THEN
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('PR_OBT_DATOS_EMPRESA - La empresa no posee transaccion padre de debito '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(P_CTADBSU, to_number(substr(P_CTADBSU,1,5)),trunc(p_fec_hoy),997,
                                                       null,null,'S',310,p_lugar);
            RAISE_APPLICATION_ERROR(-20310,'ATENCION. La empresa no posee Transacción Padre de Débito. Verifique!!!');
        end if;

        p_trancom := fug_obt_parentes(p_empresa, 'COD_TRA_COMISION');
        --if p_trancom IS NULL then
        --RAISE_APPLICATION_ERROR(-20320,'ATENCION. La empresa no posee Trans.COMISION . Verifique!!!');
        --end if;

        p_tranexc := fug_obt_parentes(p_empresa, 'COD_TRA_COM_EXCESO');
        --  if p_tranexc IS NULL then
--   RAISE_APPLICATION_ERROR(-20330,'ATENCION. La empresa no posee trans.COMIS.X EXCESO . Verifique!!!');
--  end if;

        p_tranpagui := fug_obt_parentes(p_empresa, 'COD_TRA_PAD_AGUINALDO');
        --  if p_tranpagui is null then
--   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee trans.PADRE AGUINALDO . Verifique!!!');
--  end if;

        p_tranpcom := fug_obt_parentes(p_empresa, 'COD_TRA_PAD_COMISION');
        --  if p_tranpcom is null then
--   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee trans.PADRE COMISION . Verifique!!!');
--  end if;

        p_tranpcre := fug_obt_parentes(p_empresa, 'COD_TRA_PAD_CREDITO');
        --  if p_tranpcre is null then
--   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee trans.PADRE CREDITO. Verifique!!!');
--  end if;

        p_tranpgra := fug_obt_parentes(p_empresa, 'COD_TRA_PAD_GRATIFICACION');
        --  if p_tranpcre is null then
--   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee trans.PADRE CREDITO. Verifique!!!');
--  end if;

        p_deb_exceso := fug_obt_parentes(p_empresa, 'DEB_EXCESO_EMPRESA');
        --  if p_deb_exceso is null then
--   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee INDICADOR DEB.X EXCESO. Verifique!!!');
--  end if;

        p_fec_inicio := to_date(fug_obt_parentes(p_empresa, 'FEC_INICIO'), 'DD/MM/YYYY');
        if p_fec_inicio is null then
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('PR_OBT_DATOS_EMPRESA - La empresa no posee fecha inicio contrato '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(P_CTADBSU, to_number(substr(P_CTADBSU,1,5)),trunc(p_fec_hoy),996,
                                                       null,null,'S',340,p_lugar);
            RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee FECHA INICIO CONTRATO . Verifique!!!');
        end if;

        p_fec_vencimiento := to_date(fug_obt_parentes(p_empresa, 'FEC_VENCIMIENTO'), 'DD/MM/YYYY');
        if p_fec_vencimiento is null then
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('PR_OBT_DATOS_EMPRESA - La empresa no posee fecha vencimiento contrato '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(P_CTADBSU, to_number(substr(P_CTADBSU,1,5)),trunc(p_fec_hoy),995,
                                                       null,null,'S',340,p_lugar);
            RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee FECHA VENCIMIENTO CONTRATO . Verifique!!!');
        end if;

        p_ser_activo := fug_obt_parentes(p_empresa, 'SER_ACTIVO');
        --  if p_ser_activo is null then
--   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee INDICADOR DE SERVICIO ACTIVO. Verifique!!!');
--  end if;

        p_can_max_trans := fug_obt_parentes(p_empresa, 'CAN_MAX_TRANSACCION');
        --  if  p_can_max_trans is null then
--   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee CANTIDAD MAX.DE TRANS. Verifique!!!');
--  end if;

        p_nro_cta_contable := fug_obt_parentes(p_empresa, 'NRO_CTA_CONTABLE');
        --if  p_nro_cta_contable is null and p_ctadbsu is null then
        --RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee NRO. de CTA. CONTABLE para Debitar Salarios. Verifique!!!');
        --end if;

        p_referencia_txt := fug_obt_parentes(p_empresa, 'REFERENCIA_TXT_SUELDO');
        if p_referencia_txt is null then
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('PR_OBT_DATOS_EMPRESA - La empresa no posee definicion para txt '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(P_CTADBSU, to_number(substr(P_CTADBSU,1,5)),trunc(p_fec_hoy),994,
                                                       null,null,'S',341,p_lugar);
            RAISE_APPLICATION_ERROR(-20341,'ATENCION. La empresa no posee DEFINICION PARA TXT . Verifique!!!');
        end if;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('PR_OBT_DATOS_EMPRESA - empresa inexistente '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(P_CTADBSU, to_number(substr(P_CTADBSU,1,5)),trunc(p_fec_hoy),993,
                                                       null,null,'S',400,p_lugar);
            RAISE_APPLICATION_ERROR(-20400,'Empresa Inexistente... Verifique.'||sqlerrm);
        WHEN TOO_MANY_ROWS THEN
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('PR_OBT_DATOS_EMPRESA - empresa duplicada '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(P_CTADBSU, to_number(substr(P_CTADBSU,1,5)),trunc(p_fec_hoy),992,
                                                       null,null,'S',450,p_lugar);
            RAISE_APPLICATION_ERROR(-20450,'Empresa Duplicada... AVISE AL ADMINISTRADOR.'||sqlerrm);
        WHEN OTHERS THEN
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('PR_OBT_DATOS_EMPRESA - error inesperado '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(P_CTADBSU, to_number(substr(P_CTADBSU,1,5)),trunc(p_fec_hoy),991,
                                                       null,null,'S',460,p_lugar);
            RAISE_APPLICATION_ERROR(-20460,'Error en pr_obt_datos_empresa '||sqlerrm);
    end pr_obt_datos_empresa;
/* Inserta en la tabla GE_PAG_SUELDOS */
    PROCEDURE LP_INS_TABLA
    (P_COD_ENTE IN NUMBER
    ,P_LUGAR OUT VARCHAR2
    ,P_NRO_SECUENCIA OUT NUMBER
    ,P_ERROR OUT VARCHAR2
    ,P_NRO_ARCHIVO IN NUMBER DEFAULT NULL
    ,P_COD_USUARIO IN VARCHAR2 DEFAULT USER
    ,P_FEC_HOY IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE DEFAULT SYSDATE
    ,P_FEC_PROCESO IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE DEFAULT NULL
    ,P_PRO_CON_ERRORES IN VARCHAR2 DEFAULT 'N')
        IS
        v_nro_cuenta   ge_pag_sueldos.nro_cuenta%type;
        v_nro_cta_tmp  ge_pag_sueldos.nro_cuenta%type;
        v_existe       char(1) := 'N';
        v_secuencia    ge_pag_sueldos.nro_secuencia%type;
        v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(3);
        v_pro_con_errores varchar2(1);
        v_mto_debito ge_pag_sueldos.monto%type;
        v_monto ge_pag_sueldos.monto%type;

        cursor c_tmp is select a.*, rowid fila
                        from ge_pag_sueldos_tmp a
                        where cod_ente = p_cod_ente
                          and usu_insercion = p_cod_usuario
                          and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
                          and trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(p_fec_proceso,p_fec_hoy));
--                    where ((cod_ente is null)
--                            or cod_ente = p_cod_ente)

        cursor c_cta is select nro_cuenta from ge_cuentas where
            nro_cuenta = v_nro_cuenta
                                                            and rownum = 1 ;
        --PRAGMA AUTONOMOUS_TRANSACTION;
    begin
        begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

        ---- verifico que no se haya procesado ya el dia de hoy
        /* -- RI : 12/10/09, se comenta, este control se lleva al form para que pida confirmacion
    declare
      v_procesado VARCHAR2(1) := 'S';
    begin
      select 'S'
       into v_procesado
       from ge_pag_sueldos_tmp a
      where ((cod_ente is null) or cod_ente = p_cod_ente)
        and tipo = 'D'
        and exists (select 0 from ge_pag_sueldos b
                     where b.cod_ente = p_cod_ente
                       and b.fec_proceso = v_fec_actual
                       and b.tipo = 'D'
                       and b.monto = a.monto
                       and cod_proceso = 0);
        raise_application_error(-20020,'El Ente ya fue procesado hoy. Verifique!');
    exception
      when no_data_found then null;
    end;   */
        -- veo si ya se proceso la empresa hoy
        begin
            select 'S', nvl(max(nro_secuencia),0)
            into v_existe, v_secuencia
            from ge_pag_sueldos
            where cod_ente = p_cod_ente
              --and fec_proceso = pag_cal.fu_obt_fec_actual(3)
              and fec_proceso = trunc(NVL(p_fec_proceso,p_fec_hoy))
              and cod_proceso = 0;
            if v_existe is null then
                raise no_data_found;
            end if;
        exception
            when no_data_found then
                v_existe := 'N';
                v_secuencia := 0;
        end;
        -- primero verifico si todas las cuentas estan en GE_CUENTAS --
        p_lugar := 'Insertando en GE_PAG_SUELDOS';

        IF NOT p_fec_proceso IS NULL THEN
            v_fec_actual := p_fec_proceso;
        END IF;

        for reg in c_tmp loop

                v_nro_cuenta  := reg.nro_cuenta ;

                v_nro_Cta_tmp := null;

                open c_Cta;
                fetch c_cta into v_nro_Cta_tmp;
                close c_Cta;

                /*RI : 23/02/2010 : cuando es rubro contable en la cuenta debito
          se recibe 999999999999999 */
                if v_nro_cta_tmp is null
                    and reg.nro_cuenta <> '999999999999999' and p_pro_con_errores = 'C' then
                    update ge_pag_sueldos_tmp set cod_proceso=12 --CTA INEXISTENTE --
                    where rowid = reg.fila;
                    P_ERROR :='S';
                    exit;
                else
                    --Verificar el monto del crédito contra el Débito
                    begin
                        select sum(a.monto)
                        into v_mto_debito
                        from ge_pag_sueldos_tmp a
                        where cod_ente = p_cod_ente
                          and usu_insercion = p_cod_usuario
                          and nvl(nro_archivo, 0) = nvl(p_nro_archivo, 0)
                          and trunc(nvl(fec_proceso,fec_insercion)) = trunc(nvl(p_fec_proceso,p_fec_hoy))
                          and a.tipo = 'C';
                    exception
                        when no_data_found then
                            raise_application_error(-20807,'No se encuentran Ctas. de Crédito.'||sqlerrm);
                    end;
                    if reg.tipo = 'D' and v_mto_debito <> reg.monto and p_pro_con_errores = 'N' then
                        v_monto := v_mto_debito;
                    else
                        v_monto := reg.monto;
                    end if;

                    insert into ge_pag_sueldos
                    (cod_ente, fec_proceso, nro_secuencia, nro_cuenta,
                     cod_moneda, fec_envio, tipo, monto, estado,
                     cod_proceso, cod_modulo,cod_modalidad, ano, nivel, entidad, observacion,nro_documento, nro_lote)
                    select cod_ente, trunc(NVL(p_fec_proceso,p_fec_hoy)), p_nro_archivo, nro_cuenta, --v_secuencia+1
                           cod_moneda, fec_envio, tipo, v_monto, estado,
                           cod_proceso, cod_modulo,cod_modalidad, ano, nivel, entidad, observacion,nro_documento, nro_lote
                    from ge_pag_sueldos_tmp
                    where rowid = reg.fila
                      and nro_lote = reg.nro_lote;
                    ---SE INVOCA AL PROCEDIMIENTO PRG_ACT_CTA_ENTES QUE ACTUALIZA DATOS EN LA TABLA
                    prg_act_cta_entes(reg.nro_cuenta,reg.cod_ente,reg.fec_proceso,'A');
                end if;
                P_NRO_SECUENCIA := (NVL(v_secuencia,0)+1);

            end loop;
        if nvl(P_ERROR,'N') = 'N' then
            LP_DEL_DATOS_TEMPORA(p_cod_ente,v_fec_actual,p_lugar, p_nro_archivo,p_cod_usuario);
        end if;

    exception
        when others then
            P_ERROR :='S';
            --CAMBIOS ANA 20/06/2025
            p_lugar := substr('LP_INS_TABLA - error al insertar en ge_pag_sueldos '||sqlerrm|| fu_obt_ubicacion,1,200);
            pag_sue.pr_ins_errores(v_nro_cta_tmp, P_COD_ENTE,trunc(p_fec_hoy),p_nro_archivo,
                                                       null,null,'S',808,p_lugar);
            RAISE_APPLICATION_ERROR(-20808,'Error al insertar GE_PAG_SUELDOS :'||v_nro_Cta_tmp ||' '||sqlerrm);
    end lp_ins_tabla;

    procedure pr_set_cod_ente(p_cod_ente in number) is
    begin
        v_cod_ente := p_cod_ente;
    end;

    function fu_obt_cod_ente return number is
    begin
        return v_cod_ente;
    end;

    FUNCTION Fu_ver_cuenta
    (p_cta in varchar2)
        return varchar2 is
        existe number;
        v_cta  varchar2(20);
    Begin
        -- Primero verificar si la cuenta existe en ge_cuentas si no
        -- convertir al formato IT
        /*if length(p_cta) = 9 then
       v_cta := '0'||p_cta ;
    else
       v_cta := p_cta ;
    end if ;*/
        v_cta := p_cta ;

        Select count(*) into existe
        from ge_cuentas
        where nro_cuenta = v_cta;
        if  existe = 0 then
            if  substr(v_cta,4,6) in('210100','215000') then
                Select count(*) into existe
                from ge_cuentas
                where nro_cuenta = substr(v_cta,1,2)||'01'||substr(v_cta,11,6);
                if  existe = 0 then
                    return  (substr(v_cta,1,2)||'07'||substr(v_cta,11,6));
                else
                    return  (substr(v_cta,1,2)||'01'||substr(v_cta,11,6));
                end if;
            elsif substr(v_cta,4,6) in('210500','215500') then
                Select count(*) into existe
                from ge_cuentas
                where nro_cuenta = substr(v_cta,1,2)||'02'||substr(v_cta,11,6);
                if  existe = 0 then
                    return  (substr(v_cta,1,2)||'08'||substr(v_cta,11,6));
                else
                    return  (substr(v_cta,1,2)||'02'||substr(v_cta,11,6));
                end if;
            elsif substr(v_cta,4,6) = '999999' then
                return  '999999999999999';
            else
                --DYDMR-7979 - Incidencia SAU - ITGF - Incidente Pago en Forma Parcial
                return v_cta;
            End if;
        else
            return v_cta;
        end if;
    End;

    FUNCTION Fu_dec_cuenta
    (p_cta in varchar2)
        return varchar2 is
        v_long  number;
        v_exi_cta number;
        v_cta   varchar2(6);
        v_tip   varchar2(2);
        v_suc   varchar2(2);
    Begin
        v_long := length(trim(p_cta));
        v_cta  := substr(p_cta,v_long-5,6);
        if substr(p_cta,v_long-6,1) in ('1','3') then
            v_tip := '01';
        elsif substr(p_cta,v_long-6,1) in('2','4') then
            v_tip := '02';
        end if;
        v_suc  := lpad(substr(p_cta,1,v_long-7),2,'0');
        --- Verificar si existe en Ge_cuentas porque con el nuevo formato de IT
        --- puede variar la posicion 3 y 4.
        Select count(*) into v_exi_cta
        from ge_cuentas
        where nro_cuenta = v_suc||v_tip||v_cta;
        if  v_Exi_cta = 0 then
            if  v_tip = '01' then
                v_tip := '08';
                Select count(*) into v_exi_cta
                from ge_cuentas
                where nro_cuenta = v_suc||v_tip||v_cta;
                if  v_Exi_cta = 0 then
                    v_tip := '04';
                    Select count(*) into v_exi_cta
                    from ge_cuentas
                    where nro_cuenta = v_suc||v_tip||v_cta;
                end if;
            else
                v_tip := '07';
                Select count(*) into v_exi_cta
                from ge_cuentas
                where nro_cuenta = v_suc||v_tip||v_cta;
            end if;
        end if;
        if  v_exi_cta = 0 then
            -- si no existe ninguno de los dos formatos entonces devolver
            -- la cuenta original para que arroje error en el proceso
            -- de verificacion de cuenta
            return p_cta;
        else
            return v_suc||v_tip||v_cta;
        end if;
    End;

    FUNCTION Fu_cod_cuenta
    (p_cta in varchar2)
        return varchar2 is
        v_mon   varchar2(3);
        v_mod   number;
        v_cta   varchar2(6);
        v_tip   varchar2(1);
        v_suc   number;
    Begin
        Begin
            select cod_moneda, cod_modalidad
            into v_mon, v_mod
            from ge_cuentas
            where nro_cuenta = p_cta;
        Exception
            when others then
                return null;
            --RAISE_APPLICATION_ERROR(-20808,'Error al buscar moneda de la cuenta : '||p_cta||' - ' ||sqlerrm);
        End;
        -- Sucursal
        v_suc := to_number(substr(p_Cta,1,2));
        -- Tipo de cuenta
        If v_mod = 41 then   -- cta cte.
            if  v_mon = pag_gen.fu_obt_mon_local then
                v_tip := '1';
            else
                v_tip := '3';
            end if;
        elsif v_mod = 31 then  -- Ahorro
            if  v_mon = pag_gen.fu_obt_mon_local then
                v_tip := '2';
            else
                v_tip := '4';
            end if;
        end if;
        v_cta  := substr(p_cta,5,6);
        return v_suc||v_tip||v_cta;
    End;

    FUNCTION Fu_obt_mon_rubro
    (p_rubro in varchar2)
        return varchar2 is
        v_mon   cb_rubros.cod_moneda%type;
    Begin
        Begin
            select cod_moneda
            into v_mon
            from cb_rubros
            where cod_rubro = p_rubro;
        Exception
            when others then
                RAISE_APPLICATION_ERROR(-20808,'Error al buscar moneda del rubro contable : '||p_rubro||' - ' ||sqlerrm);
        End;
        return v_mon;
    End;

    /* LIQUIDACION DEL ANTICIPO DE SUELDOS Y O/ AGUINALDOS */
    PROCEDURE PR_LIQ_ANTICIPOS(p_cod_ente in number, p_tip_tra_padre in varchar2) IS
        CURSOR cuentas is
            SELECT a.nro_cuenta nro_cuenta, a.rowid fila
            FROM CC_CTA_CORRIENTES c, GE_PAG_SUELDOS A
            WHERE a.cod_ente  = p_cod_ente
              and a.fec_proceso = p_fec_hoy
              and a.COD_proceso = 0
              and a.tipo = 'C'
              and a.nro_cuenta = c.nro_cuenta
              and c.cod_ente = a.cod_ente
              and exists (select 0 from ge_pag_sue_anticipos b
                          where b.nro_cuenta = a.nro_cuenta
                            and b.liquidado = 'N');
        v_interes number;
        v_fila varchar2(200);
    BEGIN
        p_fec_hoy := pag_cal.fu_obt_fec_actual(4);
        for ct in cuentas loop
                v_fila := ct.fila;
                -- invoco a la liquidacion de sobregiros
                prc_liq_sobregiros(ct.nro_cuenta);
                -- invoco a cargo adicional de aguinaldos
                v_interes := pac_sob.FU_UTI_ANTICIPOS(ct.nro_cuenta,'S', p_tip_tra_padre);
            end loop;
    EXCEPTION
        WHEN OTHERS THEN
            lp_act_ge_pag_sueldos(v_fila, 49);
            raise;
        /*      update ge_pag_sueldos
           set cod_proceso = 49
         where rowid = v_fila;*/
/*
        if sql%notfound then
           raise_application_error(-20005,'No puedo actualizar ge_pag_sueldos ');
        else
           raise;
        end if;  */
        --raise_application_error(-20005,'Error en liquidacion de Anticipos '||sqlerrm);

    END;
    --
/* Obtiene el Saldo Promedio de una Cuenta */
    FUNCTION FU_CRE_MEN_PROMEDIO
    (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
    ,P_FEC_INI IN DATE
    ,P_FEC_FIN IN DATE
    )
        RETURN NUMBER
        IS

        v_can_datos     number := 0;
        v_sal_acumulado number := 0;
        v_promedio      number := 0;
        v_redondeo      number;
        v_cod_moneda    ge_cuentas.cod_moneda%type;

        CURSOR saldo_promedio IS
            SELECT sum(monto) tot_datos, count(distinct to_char(fec_proceso,'MMYYYY')) can_datos
            FROM ge_pag_sueldos a
            where nro_cuenta = p_nro_cuenta
              and fec_proceso between p_fec_ini and P_FEC_FIN
              and cod_proceso = 0
              and tipo = 'C';

    BEGIN
        begin
            select cod_moneda into v_cod_moneda from ge_cuentas where nro_cuenta = p_nro_cuenta;
        exception
            when others then
                raise_application_error(-20000,'Error al buscar la Moneda de la Cuenta '||p_nro_cuenta||'. '||sqlerrm);
        end;
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_moneda,null);
        /* La fecha  actual se va incrementando en 1 mes. Mientras que sea menor que la fecha final
      recibida como parametros. Calcula el acumulado de saldo y el saldo promedio */
        IF saldo_promedio%ISOPEN THEN
            CLOSE saldo_promedio;
        END IF;
        OPEN saldo_promedio;
        FETCH saldo_promedio
            INTO v_sal_acumulado, v_can_datos;
        IF NVL(v_can_datos,0) > 0 THEN
            v_promedio := round(v_sal_acumulado  / v_can_datos,v_redondeo);
        END IF;
        return v_promedio;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20022,'Al obtener promedio de creditos '||SQLERRM);
    END;

    /* Obtiene la siguiente secuencia que se utilizará para el de proceso */
    FUNCTION fu_obt_sig_nro_secuencia
    (
        p_cod_ente    IN ge_pag_sue_lotes.cod_ente%TYPE,
        p_fec_proceso IN ge_pag_sue_lotes.fec_proceso%TYPE
    ) RETURN NUMBER IS

        v_nro_secuencia_1 NUMBER(3);
        v_nro_archivo NUMBER(3);
        v_nro_secuencia_2 number(3);
    BEGIN
        BEGIN

            SELECT NVL(MAX(nro_secuencia),0) + 1
            INTO v_nro_secuencia_1
            FROM ge_pag_sue_lotes s1
            WHERE s1.cod_ente = p_cod_ente
              AND trunc(s1.fec_proceso) = trunc(p_fec_proceso);
        EXCEPTION
            WHEN OTHERS THEN
                v_nro_secuencia_1:=1;
        END;
        -- FQ - SC 8089 Esto se agrega para incluir los temporales ingresados por HB
        BEGIN
            SELECT NVL(MAX(nro_archivo),0) + 1
            INTO v_nro_archivo
            FROM ge_pag_sueldos_tmp t
            WHERE t.cod_ente = p_cod_ente
              AND (trunc(t.fec_insercion) = trunc(sysdate)
                AND t.fec_proceso is null );
        EXCEPTION
            WHEN OTHERS THEN
                v_nro_archivo:=1;
        END;
        /*dydmr-1695 fm 25/03/2015*/
        --inicio ajuste
        BEGIN
            SELECT NVL(MAX(nro_secuencia),0) + 1
            INTO v_nro_secuencia_2
            FROM ge_pag_sueldos s2
            WHERE s2.cod_ente = p_cod_ente
              AND trunc(s2.fec_proceso) = trunc(p_fec_proceso);
        EXCEPTION
            WHEN OTHERS THEN
                v_nro_secuencia_2:=1;
        END;
        if v_nro_archivo > v_nro_secuencia_1 and v_nro_archivo > v_nro_secuencia_2 then
            RETURN v_nro_archivo;
        else
            if v_nro_secuencia_1 > v_nro_secuencia_2 then
                RETURN v_nro_secuencia_1;
            else
                RETURN v_nro_secuencia_2;
            end if;
        end if;
        ----fin ajuste
    EXCEPTION
        WHEN no_data_found THEN
            v_nro_secuencia_1 := 1;
            RETURN v_nro_secuencia_1;
    END;

    /* Obtiene la fecha para el proceso en el día de los Pagos de Nóminas */
    FUNCTION fu_obt_fec_proceso RETURN DATE IS

        v_hora_par NUMBER(4);
        v_hora_sys NUMBER(4) := TO_NUMBER(to_CHAR(sysdate, 'HH24MI'));
        v_val_par  VARCHAR2(100);
        v_est_modulo ba_modulos.estado%type;
    BEGIN

        SELECT val_parametro
        INTO v_val_par
        FROM ge_par_dinamicos pd
        WHERE pd.parametro = 'HOR_CIE_PAG_NOMINA';

        --    v_hora_par := TO_NUMBER(REPLACE(v_val_par, ':', ''));
        --Variable obtiene estado del modulo si es dintito a 2 entonces utiliza fecha proxima.
        v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
        --IF v_hora_sys <= v_hora_par THEN
        IF v_est_modulo = 2 THEN
            RETURN pag_cal.fu_obt_fec_actual(3);
        ELSE
            RETURN pag_cal.FU_OBT_FEC_PROXIMA(3);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN pag_cal.fu_obt_fec_actual(3);
    END;

    /* Validar si existe un pago pendiente de procesar con los mismos importes y cantidad de registros. */
    PROCEDURE pr_val_pag_duplicado
    (
        p_cod_ente      IN ge_pag_sue_lotes.cod_ente%TYPE,
        p_fec_proceso   IN ge_pag_sue_lotes.fec_proceso%TYPE,
        p_cod_usuario   IN ge_pag_sue_lotes.usu_insercion%TYPE,
        p_mto_credito   IN OUT ge_pag_sue_lotes.mto_credito%TYPE,
        p_mto_debito    IN OUT ge_pag_sue_lotes.mto_debito%TYPE,
        p_can_registros IN OUT ge_pag_sue_lotes.cantidad%TYPE,
        p_can_lotes     IN OUT ge_pag_sue_lotes.cantidad%TYPE
    ) IS

    BEGIN
        p_mto_debito    := 0;
        p_mto_debito    := 0;
        p_can_registros := 0;
        p_can_lotes     := 0;

        -- Se verifican los datos leidos....
        SELECT SUM(decode(tipo, 'D', monto, 0)) tot_debito, SUM(decode(tipo, 'C', monto, 0)) tot_credito, COUNT(*)
        INTO p_mto_debito, p_mto_credito, p_can_registros
        FROM ge_pag_sueldos_tmp
        WHERE cod_ente = p_cod_ente
          AND nvl(estado, 'P') = 'P';

        IF p_can_registros > 0 THEN
            -- Verificar si ya existe
            begin
                SELECT COUNT(*) cantidad
                INTO p_can_lotes
                FROM ge_pag_sue_lotes s1
                WHERE s1.cod_ente = p_cod_ente
                  AND s1.cantidad = p_can_registros
                  AND trunc(fec_proceso)= trunc(p_fec_proceso)
                  AND s1.estado = 'P';
            exception
                when no_data_found then
                    p_can_lotes := 0;
            end;
        END IF;
    END;

    /* Ejecutar los pagos en Batch, que quedaron en estado "Pendiente" de acreditación,
     será ejecutado en forma automática en el proceso de cierre diario del sistema. */
    PROCEDURE pr_pag_sue_lotes(p_tip_pag_sueldo VARCHAR2,
                               p_cod_ente IN ge_pag_sue_lotes.cod_ente%TYPE DEFAULT NULL,
                               p_nro_secuencia IN NUMBER DEFAULT NULL)  IS
        v_fec_proceso      DATE := pag_cal.fu_obt_fec_actual(1);
        v_des_ente         VARCHAR2(300);
        v_cod_tra_padre    ge_transacciones.cod_transaccion%TYPE;
        v_lugar            VARCHAR2(4000);
        v_can_error        NUMBER;
        v_tot_cre_cabecera NUMBER;
        v_tot_cre_detalle  NUMBER;
        v_tot_deb_detalle  NUMBER;
        v_can_cre_detalle  NUMBER;
        v_error            VARCHAR2(1000);
        v_pto_error        VARCHAR2(1000);
        v_verificacion_ok  VARCHAR2(10);
        v_reprocesa        VARCHAR2(1) := 'N';
        v_cod_respuesta    number(3);
        v_secuencia        ge_pag_sue_lotes.nro_secuencia%TYPE;
        v_cod_modulo       number(03);
        v_cod_modalidad    number(03);
        v_sal_disp         number(18,2);
        v_estado_nuevo     varchar2(01);
        v_procesar         varchar2(01);
        v_email_general    varchar2(100);
        v_email_sueldo     varchar2(100);
        v_email_cliente    varchar2(100);
        v_email_sueldo_capta varchar2(100);
        v_hora             varchar2(8) := to_char(sysdate, 'hh24:mi:ss');
        v_email_texto      varchar2(100);
        v_hora_par         varchar2(5) := NULL;
        v_hora_cierre      NUMBER(4) :=  0;
        v_pro_con_errores  varchar2(1);
        v_err_debito       varchar2(1000):= NULL;
        v_mto_debito       ge_pag_sue_lotes.mto_debito%type;
        v_can_procesado    number;
        v_cod_oficina      ge_cuentas.cod_oficina%type;
        v_cod_moneda       ge_cuentas.cod_moneda%type;
        v_estado           ge_cuentas.estado%type;
        v_cod_mod_cta_deb  ge_cuentas.cod_modulo%type;
        v_cod_mad_cta_deb  ge_cuentas.cod_modalidad%type;
        v_procesado        number(1) default 0;
        v_cierre           varchar2(1) default 'N';
        v_cod_usu_hb       varchar2(30):= fug_obt_pardinamico('COD_USU_HOMEBANKING');
        v_cob_aut_atr_tarjetas ge_par_dinamicos.val_parametro%type;
        v_tar_cob_aut_atr_itgf ge_par_dinamicos.val_parametro%type;
        v_tar_cob_aut_atr_web ge_par_dinamicos.val_parametro%type;

        CURSOR cu_reg(p_cod_ente VARCHAR2, p_fec_proceso DATE, p_nro_secuencia VARCHAR2) is
            SELECT *
            FROM ge_pag_sueldos_tmp
            WHERE
                cod_ente = p_cod_ente
              AND TRUNC(fec_proceso) = TRUNC(p_fec_proceso)
              AND nvl(nro_archivo, nro_secuencia) = p_nro_secuencia
              AND tipo = 'C';

        CURSOR cu_entes is
            SELECT g.tip_pago, g.cod_ente, g.nro_cta_debito,
                   g.nro_secuencia, g.usu_insercion, g.fec_insercion,
                   g.mto_debito, g.tip_ingreso, g.cantidad,
                   g.fec_proceso, g.cod_moneda
            FROM ge_pag_sue_lotes g
            WHERE (g.cod_ente   = p_cod_ente or p_cod_ente is null)
              AND (g.nro_secuencia = p_nro_secuencia or p_nro_secuencia is null)
              AND g.estado      = 'P'
              AND TRUNC(g.fec_proceso) <= TRUNC(v_fec_proceso) -- DYDMR-8105 ITGF - Ajustes para Pago de Salarios SC 15547
              AND g.nro_cta_debito != 'N/A'
              AND tip_proceso   = decode(nvl(p_tip_pag_sueldo, 'B'), 'R', nvl(p_tip_pag_sueldo, 'B'), tip_proceso)
            order by cod_ente, nro_secuencia;


    BEGIN

        v_email_sueldo := fug_obt_pardinamico('SUE_DIR_CORREO',null,null,null,null);
        v_email_general := fug_obt_dir_correo;
        -- AGREGADO PARA INFORMAR A CAPTACIONES EN CASO DE ERRORES -- DDEVOLUT-101
        v_email_sueldo_capta := fug_obt_pardinamico('SUE_DIR_MAI_CAPTACIONES');-- email para captaciones

        if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPAGSUE' then
            v_form := 'N'; --No es se ejecuta desde el form
        end if;
        if nvl(PAE_CNF.G_PROGRAMA,'x') = 'GPPROFIN' then
            v_cierre := 'S'; --se ejecuta desde el cierre para control de fecha futura
        end if;
        v_hora_par := NVL(fug_obt_pardinamico('HOR_CIE_PAG_NOMINA'), TO_NUMBER(to_CHAR(sysdate, 'HH24MI')));
        v_hora_cierre := TO_NUMBER(REPLACE(v_hora_par, ':', ''));


        -- OMM 19/01/2014. Ya no se necesita refrescar la vista para el debito automático utiliza cursores fijos.
        /*IF nvl(p_tip_pag_sueldo, 'B') = 'R' THEN
        dbms_mview.refresh('PV_CUO_PENDIENTES');
        dbms_mview.refresh('PV_DEB_AUTOMATICO');
     END IF;*/

        FOR k IN cu_entes LOOP
                v_secuencia := k.nro_secuencia;
                v_pro_con_errores := UPPER(nvl(fug_obt_parentes(k.cod_ente,'PRO_CON_ERRORES'),'N'));

                /*--Salta los lotes cuya hora de insercion sea mayor al horario de cierre
        IF NOT(
           trunc(rg_gpslo.fec_insercion) = v_fec_proceso
           AND TO_NUMBER(to_CHAR(rg_gpslo.fec_insercion, 'HH24MI')) > v_hora_cierre) THEN*/

                /*--Salta los lotes cuya hora de insercion sea mayor al horario de cierre o el usuario tenga
              asignado el rol que le permite procesar fuera del horario de cierre*/
                IF (P_TIP_PAG_SUELDO = 'R' AND NOT(TO_NUMBER(to_CHAR(k.fec_insercion, 'HH24MI')) > v_hora_cierre)) or (P_TIP_PAG_SUELDO = 'R' and fug_val_usu_rol('PUE_PRO_REQUERIMIENTO', USER))
                    or (P_TIP_PAG_SUELDO <> 'R') THEN

                    BEGIN
                        IF k.tip_pago = 'S' THEN
                            v_cod_tra_padre := fug_obt_parentes(k.cod_ente, 'COD_TRA_PAD_SUELDO');
                        ELSIF k.tip_pago = 'A' THEN
                            v_cod_tra_padre := fug_obt_parentes(k.cod_ente, 'COD_TRA_PAD_AGUINALDO');
                            v_pro_con_errores := 'C' ; -- OMM 30/09/2014. Aguinaldo no se acredita en forma Parcial
                        ELSIF k.tip_pago = 'C' THEN
                            v_cod_tra_padre := fug_obt_parentes(k.cod_ente, 'COD_TRA_PAD_COMISION');
                        ELSIF k.tip_pago = 'T' THEN
                            v_cod_tra_padre := fug_obt_parentes(k.cod_ente, 'COD_TRA_PAD_CREDITO');
                        END IF;

                        --Punto de reversion
                        SAVEPOINT punto_reversion;
                        v_pto_error := ' (Ente: ' || k.cod_ente  || '/ Archivo:' || v_secuencia ||
                                       ' cta. ' || k.nro_cta_debito || ')';
                    EXCEPTION
                        WHEN OTHERS THEN
                            it_mail.mail(v_email_general,
                                         v_email_sueldo || '; ' || v_email_sueldo_capta,
                                         'Pago de Sueldos Cancelado',
                                         v_pto_error || '. Obtención de valores. ' || SQLERRM);
                            BEGIN
                                ROLLBACK TO punto_reversion;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    NULL;
                            END;
                    END;
                    BEGIN
                        SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda, a.estado
                        INTO v_cod_mod_cta_deb, v_cod_mad_cta_deb, v_cod_oficina, v_cod_moneda, v_estado
                        FROM ge_cuentas a
                        WHERE a.nro_cuenta = k.nro_cta_debito;
                    END;
                    --Verificar la operacion
                    pag_cta.pr_ver_operacion(k.nro_cta_debito,
                                             v_cod_tra_padre,
                                             v_cod_mod_cta_deb,
                                             v_cod_mad_cta_deb,
                                             'D',
                                             v_cod_moneda,
                                             k.mto_debito,
                                             v_cod_oficina,
                                             v_cod_modulo,
                                             v_cod_modalidad,
                                             v_estado_nuevo,
                                             v_sal_disp,
                                             v_procesar);
                    BEGIN
                        IF v_procesar = 'N' THEN
                            v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error, '000'));
                            v_error := pag_cta.g_msj_error;

                            IF v_cod_respuesta IN(25,29,31,36) THEN
                                v_error := 'Cuenta '||k.nro_cta_debito||' con Saldo Insuficiente p/ el debito de '||v_cod_moneda||' '||k.mto_debito;

                                pag_sue.pr_env_mai_sueldo(k.cod_ente,v_fec_proceso,v_secuencia,'S');

                                IF v_cierre = 'S' THEN
                                    -- Actualiza los registros que dieron error por insuficiencia de saldo - fecha futura
                                    update ge_pag_sue_lotes
                                    set estado = 'C'
                                    where TRUNC(fec_proceso) = TRUNC(v_fec_proceso)
                                      and cod_ente = k.cod_ente
                                      and estado = 'P'
                                      and nro_secuencia = k.nro_secuencia;
                                    -- agrega los registros cancelados en la tabla de errores
                                    FOR reg IN cu_reg(k.cod_ente, k.fec_proceso, k.nro_secuencia) LOOP
                                            pr_ins_errores(
                                                    reg.nro_cuenta,
                                                    k.cod_ente,
                                                    k.fec_proceso,
                                                    k.nro_secuencia,
                                                    k.cod_moneda,
                                                    reg.monto,
                                                    reg.tipo,
                                                    '15',
                                                    'Cancelado por insuficiencia de saldo en la cuenta DEBITO');
                                        END LOOP;
                                    -- elimina del temporal
                                    pag_sue.LP_DEL_DATOS_TEMPORA(
                                            k.cod_ente,
                                            k.fec_proceso,
                                            v_lugar,
                                            k.nro_secuencia,
                                            k.usu_insercion);

                                END IF;
                            END IF;

                            it_mail.mail(v_email_general,
                                         v_email_sueldo || '; ' || v_email_sueldo_capta,
                                         'Pago de Sueldos No Procesado',
                                         v_error);
                        ELSE
                            -- procesa pago sueldo temporal
                            pag_sue.pr_ins_ge_pag_sueldo(v_verificacion_ok, k.cod_ente, k.nro_cta_debito,
                                                         v_cod_tra_padre, k.fec_insercion, v_lugar, v_can_error,
                                                         v_tot_cre_cabecera, v_tot_cre_detalle, v_tot_deb_detalle,
                                                         v_can_cre_detalle, k.nro_secuencia, k.Usu_Insercion,
                                                         v_fec_proceso,k.tip_pago);

                            IF ((nvl(v_can_error, 0) = 0 AND v_verificacion_ok = 'S')
                                OR (nvl(v_can_error, 0) <> 0 AND v_verificacion_ok = 'S' AND UPPER(nvl(fug_obt_parentes(k.cod_ente,'PRO_CON_ERRORES'),'N')) = 'N')) THEN
                                -- inserta en pago sueldo
                                pag_sue.lp_ins_tabla(k.cod_ente, v_lugar, v_secuencia,
                                                     v_error, k.nro_secuencia, k.Usu_Insercion,
                                                     k.fec_insercion, v_fec_proceso,v_pro_con_errores);
                                IF v_error IN ('X', 'S') THEN
                                    raise_application_error(-20005, 'Insertando ' || v_error || SQLERRM);
                                ELSE
                                    pag_cta.pr_set_variables(k.usu_insercion, k.fec_proceso, v_cod_tra_padre,
                                                             'N', 'N', v_secuencia, NULL,
                                                             v_cod_oficina, 3, 31);
                                    -- se puede hacer el credito
                                    --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora); OMM - No hace falta obtener Sigiente segundo
                                    v_pto_error := v_pto_error || ' Acreditando empleado';
                                    v_secuencia := k.nro_secuencia;
                                    pag_sue.pr_act_cred_empleado(v_reprocesa, k.cod_ente, v_secuencia,
                                                                 v_cod_oficina, v_fec_proceso, k.usu_insercion,
                                                                 v_lugar, v_error, k.tip_pago,
                                                                 v_hora, k.fec_insercion);
                                END IF;
                            ELSE
                                -- hubo error en la verificación
                                raise_application_error(-20005, 'Insertando pag.sue. (err.' || v_can_error || ' ver.' || v_verificacion_ok || ') - ' || v_lugar||' '|| v_error);
                            END IF;

                            -- OMM 19/01/2015. Se saca la condición, el debito automático es para todos los casos
                            --if nvl(p_tip_pag_sueldo, 'B') = 'R' THEN
                            --28/09/2016 Para que no procese dos veces.(Ya procesa en pag_sue.pr_act_cred_empleado)
                            --Cuando es llamado del GPPROSUE o del HBANK
                            IF  ((nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROSUE') and (UPPER(user) <> v_cod_usu_hb)) THEN
                                pr_pro_deb_automatico(k.cod_ente,k.nro_secuencia,
                                                      k.fec_proceso,v_err_debito);
                                IF v_err_debito is not null THEN
                                    raise_application_error(-20005, 'Error en proceso de Débito '||v_err_debito);
                                END IF;

                                --Proyecto PCCDEEVO-1046 - Optimizacion--
                                v_cob_aut_atr_tarjetas := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_TARJETAS'), 'N');
                                v_tar_cob_aut_atr_itgf := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_ITGF'), 'N');
                                v_tar_cob_aut_atr_web  := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_WEB'), 'N');
                                if v_cob_aut_atr_tarjetas = 'S' then
                                    if (((v_tar_cob_aut_atr_itgf = 'S') and (instr(upper(user),v_cod_usu_hb) = 0) and (nvl(pae_cnf.g_programa, 'X') = 'GPPAGSUE')) OR
                                        ((v_tar_cob_aut_atr_web = 'S') and  (instr(upper(user),v_cod_usu_hb) >= 1))) then
                                        prt_deb_automatico_atr(null, null, p_cod_ente, p_nro_secuencia, p_fec_hoy);
                                    end if;
                                end if;
                                -----------------------------------------
                                --end if;
                            END IF;
                            IF v_error IN ('X', 'S', 'Y','Z','C') THEN
                                raise_application_error(-20005, 'Acreditando (err.' || v_can_error || ' ver ' || v_verificacion_ok || ') - ' || v_lugar);
                            ELSIF k.tip_ingreso IN('H','I')  and v_err_debito is null THEN
                                v_procesado := 1;
                                --- Enviar mail
                                BEGIN
                                    SELECT descripcion
                                    INTO v_des_ente
                                    FROM ge_entes
                                    WHERE cod_ente = k.cod_ente;

                                    v_email_texto:= 'Pago de Sueldos ingresado por HomeBanking ha sido confirmado por el Cliente ';
                                    IF k.tip_ingreso ='I' THEN
                                        v_email_texto:= 'Pago de Sueldos procesado por el sistema ';
                                    END IF;

                                    --Recuperar el monto que se acreditó Fase  5
                                    SELECT sum(g.monto), count(*)
                                    INTO v_mto_debito, v_can_procesado
                                    FROM ge_pag_sueldos g
                                    WHERE cod_ente = k.cod_ente
                                      AND fec_proceso = k.fec_proceso
                                      AND nro_secuencia = k.nro_secuencia
                                      and tipo = 'C'
                                      AND procesaDo = 'S';
                                    v_can_procesado := v_can_procesado + 1;

                                    it_mail.mail(v_email_general,
                                                 v_email_sueldo,
                                                 'Pago de Sueldos Confirmado',
                                                 v_email_texto || chr(10) ||
                                                 'Codigo : ' || k.cod_ente || chr(10) ||
                                                 'Empresa : ' || v_des_ente || chr(10) ||
                                                 'Monto : ' || lpad(ltrim(to_char(nvl(v_mto_debito,0),'99999999999999.99')),16,' ') || chr(10) ||
                                                 'Cantidad: ' || to_char(v_can_procesado)|| chr(10) ||
                                                 'Atentamente. ');
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        NULL;
                                END;
                            END IF;
                            --actualizar a procesado
                            UPDATE ge_pag_sue_lotes
                            SET estado = 'N',
                                cantidad = v_can_procesado
                            WHERE cod_ente = k.cod_ente
                              AND fec_proceso = k.fec_proceso
                              AND nro_secuencia = k.nro_secuencia
                              AND estado = 'P';
                            if sql%notfound THEN
                                raise_application_error(-20005, 'Actualizando '
                                    || k.cod_ente || ' - '
                                    || k.fec_proceso || ' - '
                                    || k.nro_secuencia || ' - ' || v_error || SQLERRM);
                            END if;

                            /*-- Actualiza los registros que quedaron pendientes por error del día anterior

                   update ge_pag_sue_lotes
                      set estado = 'C'
                    where fec_proceso < v_fec_proceso
                      and estado = 'P';*/

                        END IF;

                    EXCEPTION
                        WHEN OTHERS THEN
                            -- Ocurrio un error, actualiza la cabecera a estado Cancelado.
                            update ge_pag_sue_lotes
                            set estado = 'C'
                            where TRUNC(fec_proceso) = TRUNC(v_fec_proceso)
                              and cod_ente = k.cod_ente
                              and estado = 'P'
                              and nro_secuencia = k.nro_secuencia;

                            it_mail.mail(v_email_general,
                                         v_email_sueldo || '; ' || v_email_sueldo_capta,
                                         'Pago de Sueldos Cancelado',
                                         v_pto_error || '. ' || SQLERRM);
                            BEGIN
                                ROLLBACK TO punto_reversion;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    NULL;
                            END;
                    END;

                    pag_sue.pr_env_mai_sueldo(k.cod_ente,v_fec_proceso,v_secuencia,'C');
                END IF; --fin salta hora cierre
            END LOOP;
        if v_procesado = 1 then
            -- Actualiza los registros que quedaron pendientes por error del día anterior
            update ge_pag_sue_lotes
            set estado = 'C'
            where fec_proceso < v_fec_proceso
              and estado = 'P';
        end if;
    END;

    PROCEDURE PR_ENV_MAI_SUELDO(p_cod_ente IN ge_pag_sueldos.cod_ente%type,
                                p_fec_proceso IN ge_pag_sueldos.fec_proceso%type,
                                p_nro_secuencia IN ge_pag_sueldos.nro_secuencia%type,
                                p_tipo IN varchar2) IS

        v_cta_debito       ge_pag_sueldos.nro_cuenta%type;
        v_fec_proceso      ge_pag_sueldos.fec_proceso%type;
        v_fec_insercion    ge_pag_sueldos.fec_insercion%type;
        v_cod_per_debito   ge_cta_clientes.cod_persona%type;
        v_cod_per_ente     ge_entes.cod_persona%type;
        v_usu_ofi_ente     ba_usuarios.cod_usuario%type;
        v_dir_mail_oficial ba_personas.dir_correo%type;
        v_cantidad         number(5);
        v_nro_documento    bw_mov_pendientes.nro_documento%type;
        v_nom_ente         ba_personas.nom_completo%type;
        v_dir_mail_deb     ba_personas.dir_correo%type;
        v_dir_mail_cap     ba_personas.dir_correo%type;
        c_dir_mail         ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');
        v_texto            varchar2(4000);
        v_dir_final_mail varchar2(500);
        v_cierre           varchar2(1) default 'N';
        -- Variables para mail
        v_conn     utl_smtp.connection;
        v_asunto   VARCHAR2(2000);
        v_mje_mail LONG;
        v_db_name  VARCHAR2(20);

        --GAC 24/05/2016 Se agrega membrete de BBVA, a pedido del usuario solicitante
        -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
        v_membrete LONG := fug_gen_template('M')|| chr(10);
        V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
        V_PIE      LONG := chr(10) ||fug_gen_template('P');
        --

    BEGIN

        IF nvl(PAE_CNF.G_PROGRAMA,'x') = 'GPPROFIN' THEN
            v_cierre := 'S';
        END IF;


        select upper(sys_context('USERENV', 'DB_NAME'))
        into v_db_name
        from dual;

        --Busco Datos del Pago Rechazado para insertar en el texto del correo
        begin
            select nro_cuenta, trunc(fec_insercion)
            into v_cta_debito, v_fec_insercion
            from ge_pag_sueldos
            where cod_ente = p_cod_ente
              and fec_proceso = p_fec_proceso
              and nro_secuencia = p_nro_secuencia
              and tipo = 'D';
        exception
            when no_data_found then
                begin
                    select nro_cuenta, trunc(fec_insercion)
                    into v_cta_debito, v_fec_insercion
                    from ge_pag_sueldos_tmp
                    where cod_ente = p_cod_ente
                      and fec_proceso = p_fec_proceso
                      and nro_archivo = p_nro_secuencia
                      and tipo = 'D';
                exception
                    when no_data_found then
                        v_cta_debito := null;
                        v_fec_insercion := null;
                end;
            when others then
                v_cta_debito := null;
                v_fec_insercion := null;
        end;

        --Guardo en las variables los datos para el correo
        v_cod_per_ente     := fue_obt_per_ente(p_cod_ente);
        v_nom_ente         := fue_obt_nom_persona(v_cod_per_ente);
        v_cod_per_debito   := fug_obt_cli_principal(v_cta_debito);
        v_dir_mail_deb     := fug_obt_parentes(p_cod_ente,'DIR_MAIL_SUE');
        v_dir_mail_cap     := fug_obt_pardinamico('SUE_DIR_CORREO');

        v_usu_ofi_ente     := fug_obt_cod_usu_oficial(v_cod_per_ente);
        v_dir_mail_oficial := fug_obt_dir_mail_usu(v_usu_ofi_ente);

        if v_dir_mail_deb is null then
            v_dir_mail_deb := fug_obt_dir_mail_per(v_cod_per_debito);
        end if;

        --Busco la cantidad de pagos rechazados por cod_proceso de ge_pag_sueldos
        begin
            select count(*)
            into v_cantidad
            from ge_pag_sueldos_err
            where cod_ente = p_cod_ente
              and fec_proceso = p_fec_proceso
              and nro_secuencia = p_nro_secuencia
              and tipo = 'C';
        exception
            when no_data_found then
                begin
                    select count(*)
                    into v_cantidad
                    from ge_pag_sueldos_tmp
                    where cod_ente = p_cod_ente
                      and fec_proceso = p_fec_proceso
                      and nro_archivo = p_nro_secuencia
                      and nvl(cod_proceso,0) <> 0
                      and tipo = 'C';
                exception
                    when no_data_found then
                        v_cantidad := 0;
                end;
            when others then
                v_cantidad := 0;
        end;

        --Busco el número de pago de bw_mov_pendientes

        begin
            select p.nro_documento, lo.fec_proceso, lo.fec_insercion
            into v_nro_documento, v_fec_proceso, v_fec_insercion
            from bw_mov_pendientes p, ge_pag_sue_lotes lo
            where  trunc(lo.fec_proceso) = trunc(to_date(p.dato2, 'DD/MM/YYYY'))
              and trunc(p.dato) = trunc(lo.cod_ente)
              and trunc(p.referencia) = (lo.nro_secuencia)
              and p.cod_tip_mensaje = '070'
              and p.estado IN ('C','P') --confirmado o pendiente
              and lo.cod_ente = p_cod_ente
              and trunc(lo.fec_proceso) = trunc(p_fec_proceso)
              and lo.nro_secuencia = p_nro_secuencia;
        exception
            when no_data_found then
                v_nro_documento := 0;
            when others then
                v_nro_documento := 0;
        end;

        --p_tipo = C (Credito) - p_tipo = S (Saldo)
        if p_tipo = 'C' then
            v_texto := '<br><br>
               <br><br>
                 Estimado Cliente: '|| upper(v_nom_ente) ||'
               <br><br>
                 Le informamos que no fueron procesadas ' || v_cantidad || ' operaciones de crédito del Pago de Salario Nro. '
                || v_nro_documento || ', registrado en fecha '|| v_fec_insercion || ' <br></br> y fecha de proceso ' || v_fec_proceso || '.' || '
               <br><br>
                 Para más detalles puede ingresar a la opción de consultas de operaciones de Pago de Nómina en la web.
               <br><br>
                 Atentamente.
               <br><br>
               <p align="center"><i><b>'|| fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
               <br><br>
               <br><br>';
        elsif (p_tipo = 'S' and v_cierre = 'S') then
            v_texto := '<br><br>
               <br><br>
                 Estimado Cliente: '|| upper(v_nom_ente) ||'
               <br><br>
                 Le informamos que fue cancelado el Pago de Salario Nro. '
                || v_nro_documento || ', correspondiente a la fecha '|| v_fec_proceso || ' y autorizado en fecha '
                || v_fec_insercion || ' <br><br> por insuficiencia de saldos en la cuenta débito.' || '
               <br><br>
                 Atentamente.
               <br><br>
               <p align="center"><i><b>'|| fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
               <br><br>
               <br><br>';
        elsif p_tipo = 'S' then
            v_texto := '<br><br>
               <br><br>
                 Estimado Cliente: '|| upper(v_nom_ente) ||'
               <br><br>
                 Le informamos que no fue realizado el Pago de Salario Nro. '
                || v_nro_documento || ', correspondiente a la fecha '|| v_fec_proceso || ' y autorizado en fecha '
                || v_fec_insercion || ' <br><br> por insuficiencia de saldos en la cuenta débito.' || '
               <br><br>
                 En caso de no realizar ningún depósito antes de las 19:00 hs los pagos serán cancelados.
               <br><br>
                 Atentamente.
               <br><br>
               <p align="center"><i><b>'|| fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
               <br><br>
               <br><br>';
        end if;

        v_asunto   := 'Rechazos Salarios';
        v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                      chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

        if v_dir_mail_deb is not null and ((v_cantidad > 0 and p_tipo = 'C') or p_tipo = 'S')
            and (v_db_name IN ('BBVA', 'CANALES')) THEN

            if v_dir_mail_oficial is not null then
                v_dir_final_mail := v_dir_final_mail ||''||v_dir_mail_oficial||';';
            end if;
            if v_dir_mail_cap is not null then
                v_dir_final_mail := v_dir_final_mail ||''||v_dir_mail_cap||';';
            end if;
            if v_dir_mail_deb is not null then
                v_dir_final_mail := v_dir_final_mail ||''||v_dir_mail_deb||';';
            end if;



            v_conn     := it_mail.begin_mail(c_dir_mail,
                                             v_dir_final_mail,
                                             v_asunto,
                                             IT_MAIL.MULTIPART_MIME_TYPE);

            it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

            it_mail.end_mail(v_conn);

        end if;

    EXCEPTION
        when others then
            raise_application_error(-20000,'PR_ENV_MAI_SUELDO '||sqlerrm);
    END;

    /* valida el formato de hora de cierre de pago a proveedores (hh24:mi) */
    PROCEDURE PR_VER_FMT_HOR_CIERRE(p_hor_cierre in ge_par_dinamicos.val_parametro%type) IS
        v_hor_cierre ge_par_dinamicos.val_parametro%type := trim(p_hor_cierre);
        v_hora       number(2);
        v_minuto     number(2);
        v_separador  varchar2(1);
        v_msj_error  varchar2(50);
        v_error      boolean := false;
    BEGIN
        if length(v_hor_cierre) <> 5 then
            v_msj_error := 'Favor ingrese en formato hh24:mi';
            v_error := true;
        else
            begin
                v_hora      := to_number(substr(v_hor_cierre, 1, 2));
                v_minuto    := to_number(substr(v_hor_cierre, 4, 2));
                v_separador := substr(v_hor_cierre, 3, 1);

                if v_minuto < 0 or v_minuto > 59 then
                    v_msj_error := 'Favor ingrese en formato hh24:mi. Minuto Inválido';
                    v_error := true;
                elsif v_hora < 0 or v_hora > 23 then
                    v_msj_error := 'Favor ingrese en formato hh24:mi. Hora Inválida';
                    v_error := true;
                elsif v_separador <> ':' then
                    v_msj_error := 'Favor ingrese en formato hh24:mi.';
                    v_error := true;
                end if;
            exception
                when others then
                    v_msj_error := 'Favor ingrese en formato hh24:mi';
                    v_error := true;
            end;
        end if;

        if v_error then
            raise_application_error(-20000, v_msj_error);
        end if;
    END;
    /* Realiza el débito automático de Préstamos, Tarjetas y Mov.Pendientes */
    PROCEDURE pr_pro_deb_automatico(p_cod_ente IN NUMBER,
                                    p_nro_secuencia IN OUT NUMBER,
                                    p_fec_hoy IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE,
                                    p_error out varchar2) IS

        v_cuenta     ge_pag_sueldos.nro_cuenta%type;
    BEGIN
        declare
            CURSOR Sdo IS
                SELECT distinct p.nro_cuenta
                FROM GE_CTA_CLIENTES R, GE_PAG_SUELDOS P
                WHERE r.nro_cuenta = p.nro_cuenta
                  and cod_ente = p_cod_ente
                  and p.nro_secuencia = p_nro_secuencia
                  and relacion = 'P'
                  and p.tipo = 'C'
                  and cod_proceso = 0
                  and fec_proceso = p_fec_hoy
                ORDER BY tipo DESC;
        BEGIN
            IF Sdo%ISOPEN THEN
                CLOSE Sdo;
            END IF;
            OPEN Sdo;
            LOOP
                FETCH Sdo INTO v_cuenta;
                EXIT WHEN Sdo%NOTFOUND;

                P_ERROR:= NULL;

                if p_cierre = 'N' then
                    pag_sue.pr_ins_log(v_cuenta,0,'DEB_AUTOMATICO','Cursor de Débito Automático');
                end if;

                begin
                    prp_deb_automatico(NULL, NULL, NULL, v_cuenta);
                EXCEPTION
                    WHEN OTHERS THEN
                        P_ERROR:= 'Préstamos '||sqlerrm;
                END;
                -- MDP-SEG_TAR_DEB / MDPSETADE-39 --
                /* begin
           pag_deb.pr_deb_seg_fra(v_cuenta);
        EXCEPTION
          WHEN OTHERS THEN
           P_ERROR:= 'Seguro c/Fraude '||sqlerrm;
        END;*/
                begin
                    prg_cob_mov_pendientes(v_cuenta);
                EXCEPTION
                    WHEN OTHERS THEN
                        P_ERROR:= 'Mov. Pendientes '||sqlerrm;
                END;

                -- Debito automatico TC GP
                BEGIN
                    prt_deb_aut_gp(v_cuenta/*,'S'*/);
                EXCEPTION
                    WHEN OTHERS THEN
                        p_error := substr('Tarjetas Global '||sqlerrm,1,4000);
                END;

            END LOOP;
        end;
    END;
    PROCEDURE pr_ins_errores
    (P_NRO_CUENTA IN VARCHAR2,
     P_COD_ENTE IN NUMBER,
     P_FEC_PROCESO IN DATE,
     P_NRO_SECUENCIA IN NUMBER,
     P_COD_MONEDA IN VARCHAR2,
     P_MONTO IN NUMBER,
     P_TIPO IN VARCHAR2,
     P_COD_ERROR IN VARCHAR2,
     P_MSJ_ERROR IN VARCHAR2) IS

        v_exi_error varchar2(1);
        cont number;
        PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    BEGIN
        Begin
            select 'S'
            into v_exi_error
            from ge_pag_sueldos_err
            where nro_cuenta = P_NRO_CUENTA
              and cod_ente = P_COD_ENTE
              and trunc(fec_proceso) = trunc(P_FEC_PROCESO)
              and nro_secuencia = P_NRO_SECUENCIA ;
            -- and cod_error = P_COD_ERROR;  --DYDMR-4750
        exception
            when no_data_found then
                begin
                    insert into ge_pag_sueldos_err(nro_cuenta,cod_ente,fec_proceso, nro_secuencia,
                                                   cod_moneda,monto,tipo,cod_error,msj_error)
                    values(p_nro_cuenta, p_cod_ente,trunc(p_fec_proceso),p_nro_secuencia,
                           p_cod_moneda,p_monto,p_tipo,p_cod_error,p_msj_error);
                exception
                    when others then
                        raise_application_error(-20009, 'Error-tab_err:'||sqlerrm);
                end;
            when too_many_rows then
                v_exi_error := 'S';
            when others then
                v_exi_error := 'S';
        end;
        -- 25/08/2016 OMM DYDMR-4750 No debe intentar registrar si ya existe, se debe actualizar el error
        IF v_exi_error = 'S' THEN
            update ge_pag_sueldos_err e
            set e.cod_error   = p_cod_error,
                e.observacion = substr(e.msj_error||e.observacion,1,2000),
                e.msj_error   = substr(p_msj_error,1,200)
            where e.nro_cuenta   = p_nro_cuenta
              and e.cod_ente     = p_cod_ente
              and trunc(e.fec_proceso) = trunc(p_fec_proceso)
              and e.nro_secuencia= p_nro_secuencia ;
        END IF;
        commit;
    exception
        when others then
            raise_application_error(-20015, 'Error:'||sqlerrm);
    END;
    PROCEDURE pr_ins_log(p_nro_cuenta IN VARCHAR2,
                         p_monto IN NUMBER,
                         p_lugar IN VARCHAR2,
                         p_observacion IN VARCHAR2) IS
        v_sal_total cc_cta_corrientes.sal_total%type;
        v_sal_retenido cc_cta_corrientes.sal_retenido%type;
        v_sal_bloqueado cc_cta_corrientes.sal_bloqueado%type;
    BEGIN
        BEGIN
            select nvl(c.sal_total,0) + nvl(v.sal_total,0),
                   nvl(c.sal_retenido,0) + nvl(v.sal_retenido,0),
                   nvl(c.sal_bloqueado,0) + nvl(v.sal_bloqueado,0)
            into v_sal_total, v_sal_retenido,v_sal_bloqueado
            from ge_cta_clientes g, cc_cta_corrientes c, ah_cta_vistas v
            where g.relacion='P'
              and g.nro_cuenta = p_nro_cuenta
              and g.nro_cuenta = c.nro_cuenta(+)
              and g.nro_cuenta = v.nro_cuenta(+);
        EXCEPTION
            WHEN OTHERS THEN
                null;
        END;

        BEGIN
            insert into tm_log_nominas (nro_cuenta, monto, sal_total,sal_retenido,sal_bloqueado,lugar, observacion)
            values (p_nro_cuenta, p_monto, v_sal_total,v_sal_retenido,v_sal_bloqueado, p_lugar, p_observacion);
        EXCEPTION
            WHEN OTHERS THEN
                null;
        END;
    END;
    FUNCTION FU_VER_CTA_DOCUMENTO(p_nro_documento varchar2, p_cuenta varchar2)
        return varchar2 is
        v_existe varchar2(1);
    begin
        select distinct('S')
        into v_existe
        from ge_cta_clientes a, ba_personas b
        where a.cod_persona = b.cod_persona
          and a.nro_cuenta = p_cuenta
          and a.relacion = 'P'
          and b.nro_documento = p_nro_documento;
        if v_existe = 'S' then
            return v_existe;
        end if;
    exception
        when no_data_found then
            v_existe := 'N';
            return v_existe;
        when others then
            v_existe := 'N';
            return v_existe;
    end;
END PAG_SUE;
/
