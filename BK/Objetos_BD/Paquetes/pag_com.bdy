CREATE OR REPLACE PACKAGE BODY IT.PAG_COM IS
----*
v_cod_bancard ge_entes.cod_ente%TYPE := fug_obt_pardinamico('COD_PAG_COM_BANCARD');
PROCEDURE PR_VER_PAG_COMERCIO
 (P_DATOS IN OUT VARCHAR2
 ,P_REPROCESA IN OUT VARCHAR2
 ,P_FECHA IN OUT DATE
 ,P_COD_ENTE IN NUMBER
 ,P_LUGAR IN OUT VARCHAR2
 )
 IS
------------------------------------------------------------
/* Verifica si no existe algo a reprocesar o sin procesar */
BEGIN
   p_lugar := 'VERIFICA DATOS EN GE_PAG_COMERCIOS ';
 -- Se busca si existe algún debito no procesado para la empresa, lo que significa que no es
 -- un reproceso
   p_datos     := 'S';
   p_reprocesa := 'N';
       SELECT FEC_PROCESO
         INTO p_fecha
         FROM GE_PAG_COMERCIOS
        WHERE cod_ente = p_cod_ente
          AND (COD_PROCESO   <> 0); -- Devuelve datos con error
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           -- Se busca que exista algún credito sin procesar de la Empresa
           BEGIN
            SELECT DISTINCT FEC_PROCESO
              INTO p_fecha
              FROM GE_PAG_COMERCIOS
             WHERE cod_ente = p_cod_ente
               AND COD_PROCESO   <> 0;
            p_reprocesa := 'S';
           EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 p_datos := 'N';
              WHEN TOO_MANY_ROWS THEN
                 p_reprocesa := 'S';
               SELECT MIN(FEC_PROCESO_REAL)
                 INTO p_fecha
                 FROM GE_PAG_COMERCIOS
                WHERE cod_ente = p_cod_ente
                  AND COD_PROCESO <> 0;
           END;
        WHEN TOO_MANY_ROWS THEN
           -- Existe varios dias sin procesarse
           SELECT MIN(FEC_PROCESO_REAL)
             INTO p_fecha
             FROM GE_PAG_COMERCIOS
            WHERE cod_ente = p_cod_ente
            AND (COD_PROCESO   <> 0);
WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20830,'ERROR. en PR_VER_PAG_COMERCIO . Verifique !!!'||sqlerrm);
END PR_VER_PAG_COMERCIO;
PROCEDURE PR_ACT_CRED_COMERCIO
 (P_REPROCESO IN OUT VARCHAR2
 ,P_COD_ENTE IN NUMBER
 ,P_CDOFICI IN NUMBER
 ,P_FEC_HOY IN GE_PAG_COMERCIOS.FEC_PROCESO%TYPE
 ,P_HORA IN varchar2
 ,P_USUARIO IN VARCHAR2
 ,P_LUGAR IN OUT VARCHAR2
 ,P_HUBO_ERROR OUT VARCHAR2
 )
 IS
------------------------------
/* Procesa los movimientos */
Begin
declare
 v_hrmovim    VARCHAR2(08):= P_HORA;
BEGIN
   pae_cnf.PR_CTR_MODULO(3);
   --
   p_lugar := 'proc: PR_ACT_CRED_COMERCIO :llama a LP_INS_MOV_COMERCIO Procesar movimiento';

   LP_INS_MOV_COMERCIO(p_hubo_error,v_hrmovim,p_reproceso,p_cod_ente,p_lugar,p_cdofici, p_fec_hoy, p_usuario);
   IF p_hubo_error = 'S'   THEN
      --RAISE_APPLICATION_ERROR(-20800,'ERROR. en proc: PR_ACT_CRED_COMERCIO .Verifique !!!'||pag_cta.fu_obt_msj_error||' '||pag_cta.G_CTAS.nro_cuenta );

      p_lugar := 'proc: PR_ACT_CRED_COMERCIO : llama a LP_DEL_DATOS_TEMPORALES - Borra Datos Temporales ';
      LP_DEL_DATOS_TEMP(p_cod_ente,p_Fec_hoy,p_lugar);

      p_lugar := 'proc: PR_ACT_CRED_COMERCIO : llama a LP_INS_ERROR_PROCESO - cod error de proceso ';
      LP_INS_ERROR_PROC(p_cod_ente,p_Fec_hoy,p_lugar);

  ELSIF P_hubo_error = 'N' and P_REPROCESO = 'S' THEN
     UPDATE GE_PAG_COMERCIOS
            SET FEC_PROCESO = TO_DATE(TO_CHAR(p_fec_hoy,'DD/MM/YYYY ')||HOR_PROCESO,'DD/MM/YYYY HH24:MI:SS'),
                COD_PROCESO = 0, ESTADO = 'R'
          WHERE COD_PROCESO = 99;
   ELSIF p_hubo_error = 'N' and P_REPROCESO = 'N' THEN
       -- Marcar Datos procesados y a procesar
      --Estado: N Correcto  P: Pendiente de Deb-Cred    R: Proceso Deb-Cred realizado
      --   Cambiar a R las que se procesaron en la Fecha
      Begin

       p_lugar := 'proc: PR_ACT_CRED_COMERCIO :  Cambiar a pendiente las que NO se van a procesar en la Fecha';
        UPDATE ge_pag_comercios
           SET ESTADO = 'P'
         WHERE cod_ente = p_cod_ente
          AND FEC_PROCESO = p_fec_hoy
          AND  COD_PROCESO  <> 0;

       p_lugar := 'proc: PR_ACT_CRED_COMERCIO :  Pasar Codigos de procesos a 99. Estado OK';
        UPDATE ge_pag_comercios
              SET COD_PROCESO = 99 , ESTADO = 'R'
         WHERE cod_ente = p_cod_ente
          AND  FEC_PROCESO = p_fec_hoy
          AND  COD_PROCESO = 0;

       p_lugar := 'proc: PR_ACT_CRED_COMERCIO :  Marcar como realizado todo lo de la fecha';
        UPDATE ge_pag_comercios
              SET ESTADO = 'R'
         WHERE cod_ente = p_cod_ente
          --AND FEC_PROCESO = p_fec_hoy
          AND  FEC_PROCESO_REAL <= p_fec_hoy
          AND COD_PROCESO = 99;

	          -- Dejar estado 0 sin errores
          p_lugar := 'proc: PR_ACT_CRED_COMERCIO :  Marcar como Realizadas con codigo 0';
          UPDATE GE_PAG_COMERCIOS
            SET FEC_PROCESO = TO_DATE(TO_CHAR(p_fec_hoy,'DD/MM/YYYY ')||HOR_PROCESO,'DD/MM/YYYY HH24:MI:SS'),
                COD_PROCESO = 0
          WHERE COD_PROCESO = 99;

	          p_lugar := 'proc: PR_ACT_CRED_COMERCIO :  Marcar como ignoradas Operaciones con monto Cero';

          UPDATE GE_PAG_COMERCIOS
            SET FEC_PROCESO = TO_DATE(TO_CHAR(p_fec_hoy,'DD/MM/YYYY ')||HOR_PROCESO,'DD/MM/YYYY HH24:MI:SS'),
                ESTADO = 'X'
          WHERE MONTO = 0;

        Exception
        when others then
          RAISE_APPLICATION_ERROR(-20899,'Al actualizar datos del Proceso.' ||p_lugar || '. ' ||sqlerrm);
        end;
      -- Eliminar datos del archivo temporal
      LP_DEL_DATOS_TEMP(p_cod_ente,p_Fec_hoy,p_lugar);

      p_lugar := 'proc: PR_ACT_CRED_COMERCIO : Proceso Terminado sin Errores ....';

      if p_cod_ente = v_cod_bancard then
        Begin
          p_lugar := 'proc: PR_ACT_CRED_COM_DET :  Cambiar a pendiente las que NO se van a procesar en la Fecha';

          UPDATE ge_pag_comercios_det
             SET ESTADO = 'P'
           WHERE cod_ente = p_cod_ente
             AND FEC_PROCESO = p_fec_hoy
             AND  COD_PROCESO  <> 0;

          p_lugar := 'proc: PR_ACT_CRED_COM_DET :  Pasar Codigos de procesos a 99. Estado OK';

          UPDATE ge_pag_comercios_det
                SET COD_PROCESO = 99 , ESTADO = 'R'
           WHERE cod_ente = p_cod_ente
            AND  FEC_PROCESO = p_fec_hoy
            AND  COD_PROCESO = 0;

          p_lugar := 'proc: PR_ACT_CRED_COM_DET :  Marcar como realizado todo lo de la fecha';

          UPDATE ge_pag_comercios_det
                SET ESTADO = 'R'
           WHERE cod_ente = p_cod_ente
            --AND FEC_PROCESO = p_fec_hoy
            AND  FEC_PRO_REAL <= p_fec_hoy
            AND COD_PROCESO = 99;

	          -- Dejar estado 0 sin errores
          p_lugar := 'proc: PR_ACT_CRED_COM_DET :  Marcar como Realizadas con codigo 0';

            UPDATE GE_PAG_COMERCIOS_DET
              SET FEC_PROCESO = p_fec_hoy,
                  COD_PROCESO = 0
            WHERE COD_PROCESO = 99;

	          p_lugar := 'proc: PR_ACT_CRED_COM_DET :  Marcar como ignoradas Operaciones con monto Cero';

            UPDATE GE_PAG_COMERCIOS_DET
              SET FEC_PROCESO = p_fec_hoy,
                  ESTADO = 'X'
            WHERE IMPORTE = 0;

        Exception
        when others then
          RAISE_APPLICATION_ERROR(-20899,'Al actualizar datos del Proceso.' ||p_lugar || '. ' ||sqlerrm);
        end;
      -- Eliminar datos del archivo temporal
      LP_DEL_DATOS_DET_TEMP(p_cod_ente,p_Fec_hoy,p_lugar);
      p_lugar := 'proc: PR_ACT_CRED_COM_DET : Proceso Terminado sin Errores ....';
    end if;
   END IF;
END;
end pr_act_cred_comercio;

PROCEDURE LP_INS_MOV_COMERCIO
 (P_HUBO_ERROR IN OUT VARCHAR2
 ,P_HORAMOV IN OUT VARCHAR2
 ,P_REPROCESO IN VARCHAR2
 ,P_COD_ENTE IN NUMBER
 ,P_LUGAR IN OUT VARCHAR2
 ,P_CDOFICI IN NUMBER
 ,P_FEC_HOY IN GE_PAG_COMERCIOS.FEC_PROCESO%TYPE
 ,P_USUARIO IN VARCHAR2
 )
 IS
------------------------------
/* Inserta los movimientos */
begin
declare

v_cod_rub_debito      ge_pag_comercios.cod_rubro%type;
v_cod_rub_credito     ge_pag_comercios.cod_rubro%type;

CURSOR Sdo IS
   SELECT p.rowid,
          nro_secuencia,
          p.nro_cta_origen, tipo, DECODE(tipo,'D',503,'C',602,null),
          monto, r.cod_modalidad, r.cod_modulo, FEC_PROCESO
     FROM GE_CTA_CLIENTES R, GE_PAG_COMERCIOS P
    WHERE r.nro_cuenta = p.nro_cta_origen
      and cod_ente = p_cod_ente
      and relacion = 'P'
      and nvl(cod_proceso,0) = 0
      and cod_rubro is null
      and nvl(fec_proceso_real,fec_proceso) <= p_fec_hoy 
      and estado in ('N','P') -- AAP para que solo procese los faltantes
      and monto <> 0 -- AAP No tener en cuenta montos 0
    union
   SELECT p.rowid,
          nro_secuencia,
          p.nro_cta_origen, tipo, DECODE(tipo,'D',503,'C',602,null),
          monto, r.cod_modalidad, r.cod_modulo, FEC_PROCESO
     FROM GE_CTA_CLIENTES R, GE_PAG_COMERCIOS P
    WHERE r.nro_cuenta = p.nro_cta_origen
      and cod_ente = p_cod_ente
      and relacion = 'P'
      and nvl(cod_proceso,0) != 0
      and nvl(ind_reproceso,'N') = 'S'
      and cod_rubro is null
      and nvl(fec_proceso_real,fec_proceso) <= p_fec_hoy --- Modificado por ICL el 25/01/2005
      and estado in ('N','P') -- AAP para que solo procese los faltantes
      and monto <> 0 -- AAP No tener en cuenta montos 0
    ORDER BY tipo DESC;

--Movimientos Contra Rubros Contables
CURSOR Sdo2 IS
   SELECT p.rowid,
          nro_secuencia,
          p.cod_rubro, tipo, DECODE(tipo,'D',503,'C',602,null),
          monto, 41 cod_modalidad, 4 cod_modulo, FEC_PROCESO,
          cod_ofi_rubro
     FROM GE_PAG_COMERCIOS P
    WHERE cod_ente = p_cod_ente
      and nvl(cod_proceso,0) = 0
      and fec_proceso_real <= p_fec_hoy
      and estado in ('N','P')
      and cod_rubro is not null
      and monto <> 0
    union
    SELECT p.rowid,
          nro_secuencia,
          p.cod_rubro, tipo, DECODE(tipo,'D',503,'C',602,null),
          monto, 41 cod_modalidad, 4 cod_modulo, FEC_PROCESO,
          cod_ofi_rubro
     FROM GE_PAG_COMERCIOS P
    WHERE cod_ente = p_cod_ente
      and nvl(cod_proceso,0) != 0
      and nvl(ind_reproceso,'N') = 'S'
      and fec_proceso_real <= p_fec_hoy
      and estado in ('N','P')
      and cod_rubro is not null
      and monto <> 0
    ORDER BY tipo;

v_cuenta              VARCHAR2(16);
v_cuenta_db           VARCHAR2(16);
v_tpmovim             VARCHAR2(01);
v_cnmovim             VARCHAR2(35);
v_mensaje_error       VARCHAR2(200);
v_proceso_ok          VARCHAR2(01);
v_fila                VARCHAR2(18);
v_mov_error           VARCHAR2(01);
v_cdmoned             VARCHAR2(03);
v_estado_nuevo        VARCHAR2(01);
v_puede_procesar      VARCHAR2(01);
v_tiene_tp            VARCHAR2(01);
v_tpvlpor_com         VARCHAR2(01);
v_fcproce             DATE;
v_max_sec_use_fgdiari NUMBER(07) := -999;--DYDMR-7754 - 15/11/2017
v_codigo_error        NUMBER(03);
v_cdmodal             NUMBER(03);
v_cdmodul             NUMBER(03);
v_cdmodap             NUMBER(03);
v_cdmodup             NUMBER(03);
--v_cdofici             NUMBER(03);
v_cdofior             NUMBER(03);
v_tranh               NUMBER(03);
v_secuencia           NUMBER(03);
v_Sldisp              NUMBER(16,2);
v_valor_com           NUMBER(16,2);
v_valor_iva           NUMBER(16,2);
v_Cantcred            NUMBER(05);
v_Total_Credito       NUMBER(16,2);
v_Comision            NUMBER(16,2);
v_Iva                 NUMBER(16,2);
v_imtrans             NUMBER(16,2);
rg_movs               ge_movimientos%rowtype;
v_cod_mon_local       ba_monedas.cod_moneda%type;
v_cod_moneda          ba_monedas.cod_moneda%type;
---* estas variables son para obtener los datos de empresa
v_descrip varchar2(60);
v_ctadbsu               ge_par_entes.val_parametro%type;
v_tranpdb               ge_par_entes.val_parametro%type;
v_cdtasas               ge_par_entes.val_parametro%type;
v_cdtriva               ge_par_entes.val_parametro%type;
v_cdtrcom               ge_par_entes.val_parametro%type;
---* para package de tasas
--v_g_cod_transaccion   ge_transacciones.cod_transaccion%type; 31/01/05 Delia
v_g_tpvlpor           GE_TASAS.TIP_VALOR%TYPE;
v_g_vltasa            GE_TAS_FECHAS.VAL_TASA%TYPE;
v_g_fecha             GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
v_g_tipo              GE_TASAS.TIPO%TYPE;
v_g_cdmoned           VARCHAR2(03);
v_referencia          varchar2(50);
v_bancard             VARCHAR2(1);
v_reg_a_procesar      Number;
v_existen_datos       varchar2(1):= 'N';

r_gmovi               ge_movimientos%rowtype;
v_cod_ofi             ba_oficinas.cod_oficina%type;
v_ofi                 ba_oficinas.cod_oficina%type;


BEGIN

   select cod_oficina
     into v_cod_ofi
     from ba_usuarios z
    where z.cod_usuario = substr(user,1,10);

   v_cod_rub_debito := fug_obt_parentes(p_cod_ente,'COD_RUB_TOT_DEBITO');
   v_cod_rub_credito := fug_obt_parentes(p_cod_ente,'COD_RUB_CRE_PENDIENTE');
   v_cnmovim := 'Pago de Comercio ';
    v_mov_error := 'N';

   PR_OBT_DATOS_EMPRE(p_cod_ente,v_descrip,v_ctadbsu, v_tranpdb ,
   v_cdtasas, v_cdtriva, v_cdtrcom, p_lugar, v_referencia,v_bancard);

  
   -- obtiene una hora unica para todos los movimientos a ser insertados
   IF p_horamov IS NULL THEN
      p_horamov := TO_CHAR(SYSDATE,'HH24:MI:SS');
   END IF;
   --
   IF v_ctadbsu IS NOT NULL THEN
       begin
        SELECT b.nro_cuenta,B.cod_moneda,B.cod_oficina,
               b.cod_modulo, b.cod_modalidad
          INTO v_cuenta_db,v_cdmoned, v_cdofior,--,v_cdofici,
               v_cdmodup, v_cdmodap
          FROM ge_cuentas B
         WHERE B.NRO_CUENTA = v_ctadbsu;
        exception
        when No_data_found then
          RAISE_APPLICATION_ERROR(-20450,'Error al buscr cdmodup en LP_INS_MOV_COMERCIO '||sqlerrm);
        when others then
         RAISE_APPLICATION_ERROR(-20450,'Error al buscr cdmodup en LP_INS_MOV_COMERCIO '||sqlerrm);
        end;
        
         
    ELSE
           BEGIN
              SELECT q.cod_moneda, 4, 41, v_cod_ofi
                INTO v_cdmoned, v_cdmodup, v_cdmodap, v_cdofior
                FROM cb_rubros q
               WHERE q.cod_rubro = v_cod_rub_debito;
           EXCEPTION
              WHEN OTHERS THEN
                 raise_application_error(-20599, 'Error al buscar Cuenta ' || v_cod_rub_debito);
           END;
    END IF;
   v_reg_a_procesar := 0;
   IF Sdo%ISOPEN THEN
      CLOSE Sdo;
   END IF;
   OPEN Sdo;
   LOOP
       FETCH Sdo INTO v_fila, v_secuencia, v_cuenta, v_tpmovim, v_tranh, v_imtrans,
       v_cdmodal, v_cdmodul,v_fcproce;
        EXIT WHEN Sdo%NOTFOUND OR p_hubo_error = 'S';
          p_lugar := 'Procesando Pago Comercio Cuenta :'||v_cuenta;
          v_existen_datos := 'S';
          
             if v_max_sec_use_fgdiari = 999 then 
                v_max_sec_use_fgdiari := -999;
                p_horamov     := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
             end if;

          p_lugar := 'LP_INS_MOV_COMERCIO llama al pack: PAG_CTA.PR_ACT_OPERACION ';
          PAG_CTA.PR_ACT_OPERACION(v_cuenta,
                                   p_horamov,
                                   v_tpmovim,
                                   v_cdmoned,
                                   v_imtrans,
                                   v_tranpdb,
                                   v_tranh,
                                   p_cod_ente,
                                   NULL,
                                   v_cdofior,
                                   v_cdmodup,
                                   v_cdmodap,
                                   NULL,
                                   NULL,
                                   v_cnmovim,
                                   'S',
                                   v_max_sec_use_fgdiari,
                                   p_fec_hoy--v_fcproce
                                   );
     
         v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
         v_mensaje_error := pag_cta.fu_obt_msj_error;
         v_codigo_error  := pag_cta.fu_obt_cod_error;
         -- AAP - Si v_bancard = 'S' dejar pasar saldo insuficinente
         if v_codigo_error = 25 and v_bancard = 'S' then
             p_lugar:= 'Generando autorizacion Previa...';
              -- Crea una autorizacion previa
             Begin
                INSERT INTO ge_autorizaciones
                  (cod_autorizacion, fecha, hora, nro_cuenta,
                   cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion, cod_modulo,
                   cod_modalidad, valor, fec_vencimiento,
                   observacion, cod_usu_autorizador,cod_moneda)
                VALUES
                  (s_cod_autorizacion.nextval, P_FEC_HOY, P_HORAMOV, v_cuenta,
                   v_tranpdb, v_cdmodup, v_cdmodap, v_tranh,  v_cdmodup,
                   v_cdmodap,  v_imtrans, P_FEC_HOY,
                   'AUTORIZACION AUTOMAT. PAGO COMERCIO BANCARD', user,null);

                  -- Bloquea el saldo
                  pag_cta.pr_act_sal_cta(v_cuenta,
                                         v_cdmodap,
                                         'C',                      --- tip_movimiento
                                         P_FEC_HOY,             --- fecha
                                         P_HORAMOV,      --- hora
                                         NULL,                     --- sal_total
                                         NULL,                     --- sal_retenido
                                         v_imtrans,                --- sal bloqueado
                                         'S',                      --- aut_pendiente
                                         'S');

              Exception
                   when others then
                   -- no pudo insertar aut_previa
                     v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                     v_mensaje_error := pag_cta.fu_obt_msj_error;
                     v_codigo_error  := pag_cta.fu_obt_cod_error;
              end;

              Begin
                p_lugar := 'LP_INS_MOV_COMERCIO Vuelvo llama al pack: despues de aut. previa';
                PAG_CTA.PR_ACT_OPERACION(v_cuenta,
                                         p_horamov,
                                         v_tpmovim,
                                         v_cdmoned,
                                         v_imtrans,
                                         v_tranpdb,
                                         v_tranh,
                                         p_cod_ente,
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
                -- Si pudo terminar seteo las variables
                -- por el error original
                v_proceso_ok    := 'S';
                v_mensaje_error := Null;
                v_codigo_error  := 0;
              Exception
                   when others then
                   -- no pudo insertar aut_previa
                     v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                     v_mensaje_error := pag_cta.fu_obt_msj_error;
                     v_codigo_error  := pag_cta.fu_obt_cod_error;
              end;
         end if;

         UPDATE ge_pag_comercios
            SET cod_proceso = v_codigo_error
          WHERE ROWID = v_fila;


         IF (v_proceso_ok = 'N' AND v_tpmovim = 'D') or
            (nvl(v_codigo_error,0) <> 0 AND nvl(P_REPROCESO,'N') = 'S') THEN
             p_hubo_error:= 'S';
             v_mov_error := 'S';
         ELSE
           Begin
             UPDATE GE_PAG_COMERCIOS
                SET COD_PROCESO = 99,-- Listo para procesar en la fecha que corresponda
                    ESTADO = 'R',
                    HOR_PROCESO = p_horamov,
                    FEC_PROCESO = TO_DATE(TO_CHAR(p_fec_hoy,'DD/MM/YYYY ')||p_horamov,'DD/MM/YYYY HH24:MI:SS'),
                    COD_USUARIO = USER
              WHERE ROWID = v_fila;
           Exception
              when others then
               RAISE_APPLICATION_ERROR(-20599,'No se puedieron Actualizar datos del proceso... Verifique.'||sqlerrm);
           end;
           IF p_cod_ente = v_cod_bancard THEN
             Begin
               UPDATE GE_PAG_COMERCIOS_DET
                  SET COD_PROCESO = 99,-- Listo para procesar en la fecha que corresponda
                      ESTADO = 'R',
                      HOR_PROCESO = p_horamov,
                      FEC_PROCESO = p_fec_hoy,
                      COD_USUARIO = USER
                where cod_ente = p_cod_ente
                  and nvl(cod_proceso,0) = 0
                  and fec_pro_real <= p_fec_hoy --- Modificado por ICL el 25/01/2005
                  and estado in ('N','P') -- AAP para que solo procese los faltantes
                  and importe <> 0; -- AAP No tener en cuenta montos 0

               -- WHERE ROWID = v_fila;
             Exception
                when others then
                 RAISE_APPLICATION_ERROR(-20599,'No se puedieron Actualizar datos del proceso... Verifique.'||sqlerrm);
             end;
           end if;
         END IF;

     --- inserta movimiento contra rubro  credito si es reproceso.
     if p_reproceso = 'S' and nvl(p_hubo_error,'N') = 'N' then
           begin
             select q.cod_moneda
               into v_cod_moneda
               from cb_rubros q
              where q.cod_rubro = v_cod_rub_credito;
           exception
             when others then
               raise_application_error(-20599,'Error al buscar Cuenta '||v_cod_rub_credito);
           end;

        INSERT INTO ge_pag_comercios
            (COD_USUARIO, FEC_PROCESO, nro_cuenta, monto, tipo, fec_envio, cod_ente, fec_proceso_real, cod_rubro, nro_secuencia,
             cod_modulo, cod_modalidad, cod_moneda, estado, cod_proceso)
         VALUES
            (USER, SYSDATE, NULL, v_imtrans, 'D', p_fec_hoy, p_cod_ente, p_fec_hoy,
             v_cod_rub_credito, 1, 4, 41, v_cod_moneda, 'R', 0);

       v_max_sec_use_fgdiari   := nvl(v_max_sec_use_fgdiari,0) + 1;
       p_lugar                 := ' Carga registro rg_movs ';
       rg_movs.cod_usuario     := user;
       rg_movs.hora            := p_horamov;
       rg_movs.nro_secuencia   := v_max_sec_use_fgdiari ;
       rg_movs.cod_modulo      := v_cdmodul;
       rg_movs.cod_modalidad   := v_cdmodal;
       rg_movs.cod_oficina     := v_cdofior;
       rg_movs.nro_cuenta      := null;
       rg_movs.cod_moneda      := v_cod_moneda;
       rg_movs.cod_tra_padre   := 36;
       rg_movs.cod_transaccion := null;
       rg_movs.fecha           := p_fec_hoy ;
       rg_movs.fec_valor       := p_fec_hoy ;
       rg_movs.nro_documento   := p_cod_ente;
       rg_movs.monto           := v_imtrans;
       rg_movs.estado          := 'N';
       rg_movs.tip_mov_rubro   := 'D';-- contramovimiento original.
       rg_movs.cod_ofi_origen  := v_cdofior;
       rg_movs.concepto        := v_cnmovim;
       rg_movs.reversado       := 'N';
       rg_movs.emi_aviso       := 'N';
       rg_movs.cod_mod_padre   := v_cdmodup;
       rg_movs.cod_rubro       := v_cod_rub_credito;
       rg_movs.cod_mad_padre   := v_cdmodap;

       p_lugar := 'LP_INS_MOV_COMERCIO llama a :PAG_GEN.PR_INS_GE_MOVIMIENTO,mov E ';
       PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N');


     end if;

         -- Contador de registros leidos
         v_reg_a_procesar := v_reg_a_procesar + 1;
           --
     END LOOP;
     IF Sdo%ISOPEN THEN
       CLOSE Sdo;
     END IF;
     p_hubo_error    := v_mov_error;
     v_cod_mon_local := pag_gen.fu_obt_mon_local;

     --Movimientos contra Rubros Contables
     -----------------------------------------------------------------------------------
     for mm in sdo2 loop
        v_proceso_ok    := 'S';
        v_mensaje_error := Null;
        v_codigo_error  := 0;
        If mm.cod_ofi_rubro is null then
          v_ofi := v_cdofior;
        else
          v_ofi := mm.cod_ofi_rubro;
        end if;

        r_gmovi := null;
        v_max_sec_use_fgdiari   := nvl(v_max_sec_use_fgdiari,0) + 1;
        r_gmovi.cod_usuario        := user;
        r_gmovi.hora               := p_horamov;
        r_gmovi.nro_secuencia      := v_max_sec_use_fgdiari;
        r_gmovi.cod_modulo         := mm.cod_modulo;
        r_gmovi.cod_modalidad      := mm.cod_modalidad;
        r_gmovi.cod_oficina        := v_ofi;
        r_gmovi.cod_ofi_origen     := v_cdofior;-- Debe ser la oficina de la procesadora
        r_gmovi.nro_documento      := p_cod_ente;
        r_gmovi.cod_moneda         := pag_gen.fu_obt_mon_local;
        r_gmovi.cod_tra_padre      := v_tranpdb;
        r_gmovi.cod_transaccion    := null;--v_tranh;
        r_gmovi.fecha              := p_fec_hoy;
        r_gmovi.fec_valor          := p_fec_hoy;
        r_gmovi.monto              := mm.monto;
        r_gmovi.estado             := 'N';
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.concepto           := 'Pago de Comercio';
        r_gmovi.cod_mod_padre      := mm.cod_modulo;
        r_gmovi.cod_mad_padre      := mm.cod_modalidad;
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.tip_mov_rubro      := mm.tipo;
        r_gmovi.cod_rubro          := mm.cod_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

        if v_proceso_ok = 'N' and mm.tipo = 'D' then
           p_hubo_error:= 's';
           v_mov_error := 's';
        else
         begin
           update ge_pag_comercios
              set cod_proceso = 99,-- listo para procesar en la fecha que corresponda
                  estado = 'R',
                  hor_proceso = p_horamov,
                  fec_proceso = to_date(to_char(p_fec_hoy,'dd/mm/yyyy ')||p_horamov,'dd/mm/yyyy hh24:mi:ss'),
                  cod_usuario = user
            where rowid = mm.rowid;
         exception
            when others then
             raise_application_error(-20599,'no se puedieron actualizar datos del proceso... verifique.'||sqlerrm);
         end;
        end if;

        --- inserta movimiento contra rubro  credito si es reproceso.
        if p_reproceso = 'S'  and nvl(p_hubo_error,'N') = 'N' then

           begin
             select q.cod_moneda
               into v_cod_moneda
               from cb_rubros q
              where q.cod_rubro = v_cod_rub_credito;
           exception
             when others then
               raise_application_error(-20599,'Error al buscar Cuenta '||v_cod_rub_credito);
           end;

          INSERT INTO ge_pag_comercios
              (nro_cuenta, monto, tipo, fec_envio, cod_ente, fec_proceso_real, cod_rubro, nro_secuencia,
               cod_modulo, cod_modalidad, cod_moneda, estado, cod_proceso)
           VALUES
              (NULL, mm.monto, 'D', p_fec_hoy, p_cod_ente, p_fec_hoy,
               v_cod_rub_credito, 1, 4, 41, v_cod_moneda, 'R', 0);

           v_max_sec_use_fgdiari      := nvl(v_max_sec_use_fgdiari,0) + 1;
           p_lugar                 := ' Carga registro rg_movs ';
           rg_movs.cod_usuario     := user;
           rg_movs.hora            := p_horamov;
           rg_movs.nro_secuencia   := v_max_sec_use_fgdiari;
           rg_movs.cod_modulo      := mm.cod_modulo;
           rg_movs.cod_modalidad   := mm.cod_modalidad;
           rg_movs.cod_oficina     := v_cdofior;
           rg_movs.nro_cuenta      := null;
           rg_movs.cod_moneda      := v_cod_moneda;
           rg_movs.cod_tra_padre   := 36;
           rg_movs.cod_transaccion := null;
           rg_movs.fecha           := p_fec_hoy ;
           rg_movs.fec_valor       := p_fec_hoy ;
           rg_movs.nro_documento   := p_cod_ente;
           rg_movs.monto           := mm.monto;
           rg_movs.estado          := 'N';
           rg_movs.tip_mov_rubro   := 'D';-- contramovimiento original.
           rg_movs.cod_ofi_origen  := v_cdofior;
           rg_movs.concepto        := v_cnmovim;
           rg_movs.reversado       := 'N';
           rg_movs.emi_aviso       := 'N';
           rg_movs.cod_rubro       := v_cod_rub_credito;
           rg_movs.cod_mod_padre   := v_cdmodup;
           rg_movs.cod_mad_padre   := v_cdmodap;

           p_lugar := 'LP_INS_MOV_COMERCIO llama a :PAG_GEN.PR_INS_GE_MOVIMIENTO,mov E ';
           PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N');

        end if;

     end loop;
     -----------------------------------------------------------------------------------

   --
   IF v_mov_error = 'N' and v_reg_a_procesar > 0
    and v_cod_rub_debito is null THEN
      p_lugar := 'LP_INS_MOV_COMERCIO llama al pack. PAG_CTA.PR_VER_OPERACION)';
      PAG_CTA.PR_VER_OPERACION(v_ctadbsu,
                               v_tranpdb,
                               v_cdmodul,
                               v_cdmodal,
                               'D',
                               v_cdmoned,
                               0,
                               v_cdofior,
                               v_cdmodup,
                               v_cdmodap,
                               v_estado_nuevo,
                               v_sldisp,
                               v_puede_procesar);
      v_mensaje_error := pag_cta.fu_obt_msj_error;
      v_codigo_error := pag_cta.fu_obt_cod_error;
      --
      p_lugar := 'LP_INS_MOV_COMERCIO llama al proc. lp_obt_datos_cuenta ';
      PAG_SUE.lp_obt_datos_cuenta(v_ctadbsu, v_tiene_tp, v_cdmoned, p_lugar);

      p_lugar := 'LP_INS_MOV_COMERCIO llama al proc. lp_obt_monto_proc ';
      lp_obt_monto_pro(v_Secuencia, p_cod_ente, v_CantCred, v_Total_Credito,P_lugar,v_ctadbsu, p_fec_hoy); -- Modificado por ICL 25/01/05

      ----------------------------------------------
      ----- Calcula Comision e Iva para La Empresa
      ----------------------------------------------

      p_lugar := 'LP_INS_MOV_COMERCIO - Procesar_Movim.Comercio - Busca Tasa Comision-Empresa';
 ---     v_g_cod_transaccion := 341;
 --- debe usar el del parametro : COD_TRA_COMISION_COM  de Entes : v_cdtrcom - Delia 31/01/05
      v_g_tpvlpor         := NULL;
      v_g_fecha           := NULL;
      v_g_tipo            := NULL;
      v_g_vltasa          := NULL;
      v_g_cdmoned         := null;
    -- AAP - Verificar si el ente tenia comision
    IF V_CDTASAS IS NOT NULL
      and v_cod_rub_debito is null THEN

        --Valor de tasa
          PAG_GEN.PR_OBT_VAL_TASA(v_cdmodul,
                                  v_cdmodal,
                                  v_cdofior,
                                  v_ctadbsu,
                                  v_cdmoned,
                                  v_CantCred,
                                  v_tiene_tp,
                                  v_cdtasas,
                                  v_cdtrcom, ---v_g_cod_transaccion, Delia 31/01/05
                                  v_fcproce,
                                  v_g_vltasa,
                                  v_g_fecha,
                                  v_g_tpvlpor,
                                  v_g_tipo);

          v_tpvlpor_com := v_g_tpvlpor;
          v_valor_com   := v_g_vltasa;

        if v_tpvlpor_com = 'P' then -- procentaje
          v_comision    := ROUND(v_Total_Credito* v_valor_com/ 100,0);
        else  -- valor --
          v_comision    := v_valor_com;
        end if;

        ----------------------------------------------------------------
        -- Hace el calculo de la comision
        ----------------------------------------------------------------
           /* Se hace el cambio de moneda si la tasa esta en otra moneda */

           IF v_g_cdmoned  <> v_cdmoned THEN

            IF v_cdmoned <> v_cod_mon_local THEN
               v_comision :=
               ROUND(NVL(v_comision,0) * pag_gen.fu_obt_cotizacion(v_cdmoned, p_fec_hoy),2);
            else
                v_comision :=
               ROUND(NVL(v_comision,0) * pag_gen.fu_obt_cotizacion(v_g_cdmoned, p_fec_hoy),0);
            END IF;

           END IF;
        ------------------------------------------------------------------------
        -- Hace el calculo del Iva de la comision  --- busca tasa
        ------------------------------------------------------------------------
   ---       v_g_cod_transaccion := 517;
   --- debe usar el del parametro : COD_TRA_IVA_COM  de Entes : v_cdtriva - Delia 31/01/05

           v_cdtasas := null;
           PAG_GEN.PR_OBT_VAL_TASA(v_cdmodul,
                                v_cdmodal,
                                v_cdofior,
                                v_ctadbsu,
                                v_cdmoned,
                                v_CantCred,
                                v_tiene_tp,
                                v_cdtasas,
                                v_cdtriva, ---v_g_cod_transaccion,  Delia 31/01/05
                                v_fcproce,
                                v_valor_iva,
                                v_g_fecha,
                                v_g_tpvlpor,
                                v_g_tipo);

          IF v_cdmoned = v_cod_mon_local THEN
             v_iva   := ROUND(v_comision   * v_valor_iva / 100,0);
          ELSE
             v_iva   := ROUND(v_comision   * v_valor_iva / 100, 2);
          END IF;
      IF  NVL(v_SlDisp,0) >= NVL(v_comision,0) + NVL(v_iva,0) AND
          NVL(v_comision,0) + NVL(v_iva,0) > 0              THEN
            --
            v_cnmovim := 'Comision pago de Comercio';
            --

            p_lugar := 'llama al pack: PAG_CTA.PR_ACT_OPERACION : pago comercio';
            PAG_CTA.PR_ACT_OPERACION(v_ctadbsu,
                                     p_horamov,
                                     'D',
                                     v_cdmoned,
                                     v_comision,
                                     v_tranpdb,
                                     v_cdtrcom,
                                     p_cod_ente,
                                     NULL,
                                     p_cdofici,
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

            if v_proceso_ok!='S' then
               RAISE_APPLICATION_ERROR(-20500,'Error en pr_act_operacion: '||v_codigo_error||v_mensaje_error);
            END IF;
            --
            v_cnmovim := 'Iva s/Imp.pago de Comercio';
            --
            p_lugar := 'LP_INS_MOV_COMERCIO llama al pack: DB Iva';

            PAG_CTA.PR_ACT_OPERACION(v_ctadbsu,
                                     p_horamov,
                                     'D',
                                     v_cdmoned,
                                     v_iva,
                                     v_tranpdb,
                                     v_cdtriva,
                                     p_cod_ente,
                                     NULL,
                                     p_cdofici,
                                     v_cdmodup,
                                     v_cdmodap,
                                     NULL,
                                     NULL,
                                     v_cnmovim,
                                     'S',
                                     v_max_sec_use_fgdiari,
                                     v_fcproce);

            v_mensaje_error := pag_cta.fu_obt_msj_error;
            v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
            v_codigo_error  := pag_cta.fu_obt_cod_error;

            if v_proceso_ok!='S' then
               RAISE_APPLICATION_ERROR(-20600,'Error en pr_act_operacion : IVA '||sqlerrm);
            END IF;
           --
      ELSIF  NVL(v_SlDisp,0) < NVL(v_comision,0) + NVL(v_iva,0) AND
             NVL(v_comision,0) + NVL(v_iva,0) > 0             THEN
         --

         v_max_sec_use_fgdiari      := nvl(v_max_sec_use_fgdiari,0) + 1;
         p_lugar                 := ' Carga registro rg_movs ';
         rg_movs.cod_usuario     := p_usuario;
         rg_movs.hora            := p_horamov;
         rg_movs.nro_secuencia   := v_max_sec_use_fgdiari  ;
         rg_movs.cod_modulo      := v_cdmodul;
         rg_movs.cod_modalidad   := v_cdmodal;
         rg_movs.cod_oficina     := v_cdofior;
         rg_movs.nro_cuenta      := v_ctadbsu;
         rg_movs.cod_moneda      := v_cdmoned;
         rg_movs.cod_tra_padre   := v_tranpdb;
         rg_movs.cod_transaccion := v_cdtrcom;
         rg_movs.fecha           := p_fec_hoy ;
         rg_movs.fec_valor       := p_fec_hoy ;
         rg_movs.nro_documento   := p_cod_ente;
         rg_movs.monto           := v_comision;
         rg_movs.est_cuenta      := 'N';
         rg_movs.estado          := 'E';
         rg_movs.cod_ofi_origen  := p_cdofici;
         rg_movs.concepto        := v_cnmovim;
         rg_movs.reversado       := 'N';
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_mod_padre   := v_cdmodup;
         rg_movs.cod_mad_padre   := v_cdmodap;

         p_lugar := 'LP_INS_MOV_COMERCIO llama a :PAG_GEN.PR_INS_GE_MOVIMIENTO,mov E ';
         PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N');

      END IF;
    END IF; -- Fin de Verificacion AAP Tasa para Comision
   END IF;
END;
end lp_ins_mov_comercio;

PROCEDURE LP_DEL_DATOS_TEMP
 (P_COD_ENTE IN NUMBER
 ,P_FEC_HOY IN DATE
 ,P_LUGAR IN OUT VARCHAR2
 )
 IS
----------------------------------------------
/* Borra los datos procesados del temporal */
begin
  p_lugar := 'Borra Cuentas de Comercios Procesados ';
    DELETE GE_PAG_COMERCIOS_TMP
      WHERE COD_ENTE    = p_cod_ente
        AND FEC_PROCESO = p_fec_hoy;
exception
 When others then
  RAISE_APPLICATION_ERROR(-20010,'ERROR al Borrar GE_PAG_COMERCIOS_TMP ');
end lp_del_datos_temp;

PROCEDURE LP_DEL_DATOS_DET_TEMP
 (P_COD_ENTE IN NUMBER
 ,P_FEC_HOY IN DATE
 ,P_LUGAR IN OUT VARCHAR2
 )
 IS
----------------------------------------------
/* Borra los datos procesados del temporal */
begin
  p_lugar := 'Borra Cuentas de Comercios Detalle Procesados ';
    DELETE GE_PAG_COMERCIOS_DET_TMP
      WHERE COD_ENTE    = p_cod_ente
        AND FEC_PROCESO = p_fec_hoy;
exception
 When others then
  RAISE_APPLICATION_ERROR(-20010,'ERROR al Borrar GE_PAG_COMERCIOS_DET_TMP ');
end LP_DEL_DATOS_DET_TEMP;

PROCEDURE LP_INS_ERROR_PROC
 (P_COD_ENTE IN NUMBER
 ,P_FEC_HOY IN DATE
 ,P_LUGAR IN OUT VARCHAR2
 )
 IS
------------------------------------------------------------
/* Inserta en el GE_PAG_COMERCIOS_TMP los registros con error */
begin
    p_lugar := 'Inserta error Cuentas de Empresas Procesadas ';
    INSERT INTO GE_PAG_COMERCIOS_TMP
          (cod_ente,
           fec_proceso,
           nro_secuencia,
           nro_cuenta,
           cod_moneda,
           fec_envio,
           tipo,
           monto,
           estado,
           cod_proceso)
         SELECT p_cod_ente,
                p_fec_hoy,
                nro_secuencia,
                nro_cuenta,
                cod_moneda,
                fec_envio,
                tipo,
                monto,
                estado,
                cod_proceso
           FROM GE_PAG_COMERCIOS
          WHERE COD_ENTE = p_cod_ente
           AND COD_proceso <> 0;
exception
 When others then
  RAISE_APPLICATION_ERROR(-20020,'ERROR insertar error GE_PAG_COMERCIOS_TMP ');
end lp_ins_error_proc;
PROCEDURE PR_ACT_DATOS_PAG
 (P_COD_ENTE IN NUMBER
 ,P_FEC_HOY IN DATE
 ,P_LUGAR IN OUT VARCHAR2
 )
 IS
---------------------------------------------
/* Verifica creditos y debitos procesados */
begin
DECLARE
  v_nrsecue     NUMBER;
  v_TCRSINPROCE NUMBER(16,2);
  v_TDBSINPROCE NUMBER(16,2);
BEGIN
  p_lugar := 'Obtiener Maxima Secuencia sin Procesar en el dia';
  BEGIN
    SELECT MAX(NRO_SECUENCIA)
      INTO v_nrsecue
      FROM GE_PAG_COMERCIOS
     WHERE COD_ENTE = p_cod_ente
       AND FEC_PROCESO = p_fec_hoy
       AND COD_PROCESO <> 0;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
       v_nrsecue := NULL;
    WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20100,'ERROR. al obtener secuencia sin procesar '||sqlerrm);
  END;
  --
  IF v_nrsecue IS NOT NULL THEN
    p_lugar := 'Suma Total de Creditos sin procesar ';
    SELECT SUM(NVL(MONTO,0))
      INTO v_tcrsinproce
      FROM GE_PAG_COMERCIOS
     WHERE COD_ENTE = p_cod_ente
       AND FEC_PROCESO = p_fec_hoy
       AND COD_PROCESO <> 0
       AND tipo = 'C'
       AND nro_secuencia = v_nrsecue;
     --
    p_lugar := 'Suma Total de Débitos sin procesar ';
    SELECT SUM(NVL(MONTO,0))
      INTO v_tdbsinproce
      FROM GE_PAG_COMERCIOS
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
   RAISE_APPLICATION_ERROR(-20200,'Existen MONTOS ya acreditados para la Empresa '
   ||TO_CHAR(p_cod_ente)||'. Imposible actualizar datos !!!' ||sqlerrm);
  ELSIF v_TDBSINPROCE = 0 THEN
   RAISE_APPLICATION_ERROR(-20250,'El Débito a la Empresa '
   ||TO_CHAR(p_cod_ente)||' fue realizado. Imposible actualizar datos !!!'||sqlerrm);
  END IF;
  --
  -- Borra los datos...
  --
      DELETE GE_PAG_COMERCIOS
       WHERE COD_ENTE = p_cod_ente
         AND FEC_PROCESO = p_fec_hoy
         AND nro_secuencia = v_nrsecue;
END;
end pr_act_datos_pag;
PROCEDURE PR_INS_GE_PAG_COM
 (P_VERIFICA_OK IN OUT VARCHAR2
 ,P_COD_ENTE IN NUMBER
 ,P_CTADBSU IN VARCHAR2
 ,P_TRANPDB IN NUMBER
 ,P_FEC_HOY IN GE_PAG_COMERCIOS.FEC_PROCESO%TYPE
 ,P_LUGAR IN OUT VARCHAR2
 ,P_CANT_ERROR OUT NUMBER
 ,P_TCRECAB OUT NUMBER
 ,P_TCREDET OUT NUMBER
 ,P_TDEBDET OUT NUMBER
 ,P_CCREDET OUT NUMBER
 )
 IS
-------------------------------------------------
/* Proceso principal de inserción y generación */
begin
declare
  /* Definición de Variables */
  v_Tot_Debito  number(16,2) := 0;
  v_Tot_Credito number(16,2) := 0;
  v_min_fec     date;
  v_max_fec     date;
  v_cantreg     number(5) := 0;
  -------------------
  v_fech_env          date;
  v_cuenta            varchar2(15);
  v_tip_movimiento    varchar2(01);
  v_mensaje_error     varchar2(200);
  v_cod_moneda        varchar2(03);
  v_cod_mon_debito    varchar2(03);
  v_est_movimiento    varchar2(01);
  v_estado_nuevo      varchar2(01);
  v_puede_procesar    varchar2(01);
  v_tas_personalizada varchar2(01);
  v_cod_modulo        number(03);
  v_cod_modalidad     number(03);
  v_cod_oficina       number(03);
  v_Sueldo            number(18,2);
  v_sldisponible      number(18,2);
  v_Secuencia         number(03);
  v_Codigo_Error      number(03);
  v_bancard           varchar2(1) := 'N';
  v_cod_rub_debito    ge_pag_comercios.cod_rubro%type;
  v_cod_rub_credito   ge_pag_comercios.cod_rubro%type;
  v_imp_errores       number(18,2);
  v_fec_proceso       ge_pag_comercios.fec_proceso%type;
--*
  cursor c1 is Select cod_usuario, cod_ente, fec_proceso,nro_secuencia,
   cod_modalidad, nro_cta_origen, cod_moneda, fec_envio,
   decode(tipo,'1','D','C') tipo,
   monto, estado, cod_proceso, cod_rubro, rowid
                 from GE_PAG_COMERCIOS_TMP
                  Order by TIPO
                   for update of estado;
BEGIN

    v_secuencia := nvl(v_secuencia,0) + 1;
    p_TCreDet := 0;
    p_TDebDet := 0;
    p_cCreDet := 0;
    p_verifica_ok := 'N';
    --v_bancard := fug_obt_parentes (P_COD_ENTE,'CRE_COM_BANCARD');
    v_bancard := 'N';
    v_cod_rub_credito := fug_obt_parentes(p_cod_ente,'COD_RUB_CRE_PENDIENTE');
    v_cod_rub_debito  := fug_obt_parentes(p_cod_ente,'COD_RUB_TOT_DEBITO');
    --------------------------------------------------------------------------------
    p_lugar := 'PR_INS_GE_PAG_COMERCIO : Verificando txt';
    BEGIN
        -- Se verifican los datos leidos....
         Select sum(decode(tipo, '1', monto, 0)) Tot_debito,
                sum(decode(tipo, '2', monto, 0)) Tot_credito,
                min(fec_envio), max(fec_envio), count(*)
           into v_Tot_debito, v_Tot_credito, v_min_fec, v_max_fec, v_cantreg
           from GE_PAG_COMERCIOS_TMP ;
         ---
         if v_cantreg = 0 then
            RAISE_APPLICATION_ERROR(-20700,'ERROR. archivo sin dato ');
         else
              v_fech_env := v_min_fec;
              p_TCreCab  := v_tot_Credito;
         end if;
      --* actualiza el cod_ente y secuencia
      begin
         update  GE_PAG_COMERCIOS_TMP set cod_ente = p_cod_ente,
                                      nro_secuencia = v_secuencia,
                                      fec_proceso   = p_fec_hoy;
         if sql%notfound then
          RAISE_APPLICATION_ERROR(-20711,'ERROR. Al actualiza GE_PAG_COMERCIOS_TMP ');
         end if;
      end;


      p_lugar := 'PR_INS_GE_PAG_COMERCIO : Obt_Datos_cuenta';
    
      IF p_ctadbsu IS NOT NULL THEN
        pag_sue.lp_obt_datos_cuenta(p_ctadbsu,v_tas_personalizada,v_cod_mon_debito,p_lugar);
      ELSE
        BEGIN
         SELECT q.cod_moneda, 4, 41
          INTO v_cod_mon_debito, v_cod_modulo, v_cod_modalidad
         FROM cb_rubros q
          WHERE q.cod_rubro = v_cod_rub_debito;
        EXCEPTION
         WHEN OTHERS THEN
         v_cod_mon_debito := NULL;
        END;
      END IF;
      
     
      --
      FOR r1 in c1 LOOP

         v_tip_movimiento := r1.tipo;

         v_cuenta := r1.nro_cta_origen;--r1.nro_cuenta;
         v_sueldo := r1.monto;

         if r1.cod_rubro is null and v_cuenta is not null then
             --Obtengo el modulo,la modalidad y la oficina de la cuenta
             BEGIN
               SELECT A.COD_MODULO,A.COD_MODALIDAD,A.COD_OFICINA,A.COD_MONEDA
                INTO v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda
                 FROM GE_CUENTAS A
                  WHERE A.NRO_CUENTA = V_CUENTA;
             EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  BEGIN
                   SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
                    INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda
                   FROM ge_cuentas a
                   WHERE a.nro_cuenta = '0'||v_cuenta;  ---> si no existe la cuenta se debe agregar un 0
                    if v_cuenta is not null then
                       v_cuenta := '0'||v_cuenta;
                    end if;
                  EXCEPTION
                   WHEN NO_dATA_FOUND THEN
                    UPDATE ge_pag_comercios_tmp SET cod_proceso = 12 WHERE ROWID = r1.rowid;
                    p_cant_error   := 1;
                    v_codigo_error := 12;
                  END; 
             
                WHEN OTHERS THEN
                /*
                update ge_pag_comercios_tmp set cod_proceso=12
                 where nro_cuenta=v_cuenta;
                */
                update ge_pag_comercios_tmp set cod_proceso=12
                 where rowid = r1.rowid;
                 p_cant_error := 1;
                 v_codigo_error:= 12;
             END;

             p_lugar := 'PR_INS_GE_PAG_COMERCIO : Verifica_Dup_En_Mov_Diario ';
             PAG_SUE.LP_VER_DUP_MOV_DIARI(v_cuenta,v_Sueldo,p_cod_ente);

             p_lugar := 'PR_INS_GE_PAG_COMERCIO :PAG_CTA.PR_VER_OPERACION : '||v_cuenta;
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
             if v_codigo_error = 25 and v_bancard = 'S' then
                v_puede_procesar    := 'S';
                v_mensaje_error := Null;
                v_codigo_error  := 0;
             end if;
         else
             begin
               select q.cod_moneda, 4, 41
                 into v_cod_moneda, v_cod_modulo, v_cod_modalidad
                 from cb_rubros q
                where q.cod_rubro = r1.cod_rubro;
             exception
               when others then
                  update ge_pag_comercios_tmp set cod_proceso=12
                   where nro_cuenta=r1.cod_rubro;
                    p_cant_error := 1;
                    v_codigo_error:= 12;
                  -- exit;

             end;

             v_puede_procesar    := 'S';
             v_mensaje_error     := Null;
            -- v_codigo_error      := 0;
         end if;

         /** Jira 2262 - AUTOMATIZACION ENVIO Y RECEPCION DE ARCHIVOS DE BANCARD
         || Validar si existe el rubro si es que está cargado.
         || Si existe el rubro no es error.**/
         if r1.cod_rubro is not null and v_codigo_error = 12 then
            v_codigo_error := 0;
            v_puede_procesar := 'S';
         end if;

         IF v_puede_procesar = 'S' AND v_cod_mon_debito = v_cod_moneda
				 and nvl(v_codigo_error,0) = 0 THEN
            v_est_movimiento := 'N'; -- Movimiento Normal
         ELSIF v_puede_procesar = 'S' AND v_cod_mon_debito <> v_cod_moneda THEN
            v_est_movimiento := 'E'; -- Movimiento Erróneo
            v_Codigo_Error := 02;
         ELSE
            v_est_movimiento := 'E'; -- Movimiento Erróneo
         END IF;
         if v_est_movimiento = 'N'  or p_cod_ente = v_cod_bancard  Then /** Jira 2262 **/
             if v_tip_movimiento = 'C' Then
                p_TCreDet := p_TCreDet + v_Sueldo;
                p_cCreDet := p_cCreDet + 1;
             else
               p_TDebDet := p_TDebDet + v_Sueldo;
             end if;
         End if;

         Update ge_pag_comercios_tmp
            set estado        = v_est_movimiento,
                cod_PROCESO   = v_codigo_error,
                cod_modalidad = v_cod_modalidad,
                cod_moneda    = v_cod_moneda,
                cod_modulo    = v_cod_modulo,
                observacion   = v_mensaje_error
          where current of c1;

          if sql%notfound then
             RAISE_APPLICATION_ERROR(-20725,'ERROR. Al actualiza ge_pag_comercios_tmp '||sqlerrm);
          end if;

      END LOOP;
    END;

   /** Jira 2262 - AUTOMATIZACION ENVIO Y RECEPCION DE ARCHIVOS DE BANCARD **/
   if p_cod_ente = v_cod_bancard  then
	  SELECT max(fec_proceso)
       INTO v_fec_proceso
       FROM ge_pag_comercios_tmp
      WHERE cod_ente = p_cod_ente;

      --------pendientes por error.
      SELECT sum(nvl(monto,0))
       INTO v_imp_errores
       FROM ge_pag_comercios_tmp
      WHERE cod_ente = p_cod_ente
        AND tipo = '2'
        AND nvl(cod_proceso,0) <> 0;
      if nvl(v_imp_errores,0)  > 0 then
         begin
            select q.cod_moneda
              into v_cod_moneda
              from cb_rubros q
             where q.cod_rubro = v_cod_rub_credito;
         exception
            when others then
               RAISE_APPLICATION_ERROR(-20740,'Error al verificar cuenta débito. ' || sqlerrm);
         end;
         INSERT INTO ge_pag_comercios_tmp
            (nro_cuenta, monto, tipo, fec_envio, cod_ente, fec_proceso_real, cod_rubro, nro_secuencia,
             cod_modulo, cod_modalidad, cod_moneda, estado, cod_proceso)
         VALUES
            (NULL, v_imp_errores, '2', v_fec_proceso, p_cod_ente, v_fec_proceso,
             v_cod_rub_credito, 1, 4, 41, v_cod_moneda, 'N', 0);
      end if;

      --Buscar Monto Total a Acreditar Sumando Debitos
      begin
         select sum(nvl(monto,0))
           into v_tot_debito
           from ge_pag_comercios_tmp
          WHERE cod_ente = p_cod_ente
            and tipo = '2'
            AND nvl(cod_proceso,0) = 0;
      exception
       when others then
          RAISE_APPLICATION_ERROR(-20741, 'Error al buscar totales debitos cta.de pago'||sqlerrm);
          return;
      end;

      if v_tot_debito > 0 then
        begin
          select q.cod_moneda
            into v_cod_moneda
            from cb_rubros q
           where q.cod_rubro = v_cod_rub_debito;
        exception
          when others then
             RAISE_APPLICATION_ERROR(-20740,'Error al verificar cuenta débito. ' || sqlerrm);
        end;
        begin
          INSERT INTO ge_pag_comercios_tmp
             (nro_cuenta, monto, tipo, fec_envio, cod_ente, fec_proceso_real, cod_rubro, nro_secuencia,
              cod_modulo, cod_modalidad, cod_moneda, estado, cod_proceso)
          VALUES
             (NULL, v_tot_debito, 1, v_fec_proceso, p_cod_ente, v_fec_proceso,
              v_cod_rub_debito, 1, 4, 41, v_cod_moneda, 'N', 0);
        exception
          when others then
             RAISE_APPLICATION_ERROR(-20741,'Error al insertar en tmp cta de debito '||sqlerrm);
             return;
        end;
      end if;

    end if;
   --------

   p_lugar :=  'PR_INS_GE_PAG_COMERCIO : Verificando ERRORES';
   BEGIN
     SELECT COUNT(*)
       INTO p_Cant_Error
       FROM ge_pag_comercios_tmp
      WHERE cod_ente = p_cod_ente
        AND fec_proceso = p_fec_hoy
        AND nro_secuencia = v_Secuencia
        and cod_proceso <> 0;
   EXCEPTION
       WHEN OTHERS THEN
         p_Cant_Error := 0;
   END;
/*
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20740,'ERROR. Verificando monto. ' || sqlerrm);
*/
END;
end pr_ins_ge_pag_com;

PROCEDURE PR_INS_GE_PAG_COM_DET
 (P_VERIFICA_OK IN OUT VARCHAR2
 ,P_COD_ENTE IN NUMBER
 ,P_TRANPDB IN NUMBER
 ,P_FEC_HOY IN GE_PAG_COMERCIOS.FEC_PROCESO%TYPE
 ,P_LUGAR IN OUT VARCHAR2
 ,P_CANT_ERROR OUT NUMBER
 ,P_TOT_IMPORTE OUT NUMBER
 )
 IS
-------------------------------------------------
/* Proceso principal de inserción y generación */
begin
declare
  /* Definición de Variables */
  v_Tot_importe  number(16,2) := 0;
  v_min_fec     date;
  v_max_fec     date;
  v_cantreg     number(5) := 0;
  -------------------
  v_fech_env          date;
  v_cuenta            varchar2(15);
  v_mensaje_error     varchar2(200);
  v_cod_moneda        varchar2(3);
  v_cod_modulo        number(3);
  v_cod_modalidad     number(3);
  v_cod_oficina       number(3);
  v_Sueldo            number(18,2);
  v_Secuencia         number(3);
  v_Codigo_Error      number(3):=0;
  v_bancard           varchar2(1) := 'N';
  v_est_movimiento    varchar2(1);
  v_exi_cta_informe   varchar2(1);
  v_est_cuenta      varchar2(01);
  v_des_estado      varchar2(100);

  --*
  cursor c1 is Select cod_usuario, cod_ente, fec_proceso,nro_secuencia,
   cod_modalidad, nro_cuenta, cod_moneda, fec_envio,
   importe, estado, cod_proceso, cod_rubro, rowid
                 from GE_PAG_COMERCIOS_DET_TMP
                  Order by nro_cuenta
                    for update of estado;
  cursor c_det_cuentas is
   select t.nro_cuenta, sum(monto), sc.monto_det
     from ge_pag_comercios_tmp t, (select fec_proceso, cod_ente, nro_cuenta, sum(importe) monto_det
                                     from ge_pag_comercios_det_tmp d
                                    group by fec_proceso, cod_ente, nro_cuenta) sc
    where trunc(t.fec_proceso) = sc.fec_proceso
      and t.cod_ente = sc.cod_ente
      and t.nro_cuenta = sc.nro_cuenta
      and exists (select 1
                    from ge_entes a, ba_cod_referencias b
                   where a.tipo='AC'
                     and a.cod_persona=b.val_maximo
                     AND B.DOMINIO='NRO_CTA_ENV_CON'
                     and t.nro_cuenta = b.val_minimo)
    group by t.nro_cuenta,sc.monto_det
    having sum(monto) <> sc.monto_det
   union all
   select d.nro_cuenta, 0, sum(importe)
     from ge_pag_comercios_det_tmp d
    where not exists (select 1 from ge_pag_comercios_tmp p
                       where d.nro_cuenta = p.nro_cuenta)
      and exists (select 1
                    from ge_entes a, ba_cod_referencias b
                   where a.tipo='AC'
                     and a.cod_persona=b.val_maximo
                     AND B.DOMINIO='NRO_CTA_ENV_CON'
                     and d.nro_cuenta = b.val_minimo)
   group by d.nro_cuenta;
BEGIN

    v_secuencia := nvl(v_secuencia,0) + 1;
    p_verifica_ok := 'N';
    --v_bancard := fug_obt_parentes (P_COD_ENTE,'CRE_COM_BANCARD');
    v_bancard := 'N';
    p_lugar := 'PR_INS_GE_PAG_COMERCIO_DET : Verificando txt';
    BEGIN
        -- Se verifican los datos leidos....
         Select sum(importe) Tot_importe,
                min(fec_envio), max(fec_envio), count(*)
           into v_Tot_importe, v_min_fec, v_max_fec, v_cantreg
           from GE_PAG_COMERCIOS_DET_TMP ;
         ---
         if v_cantreg = 0 then
            RAISE_APPLICATION_ERROR(-20700,'ERROR. archivo sin dato ');
         else
              v_fech_env := v_min_fec;
              p_tot_importe  := v_tot_importe;
         end if;
      --* actualiza el cod_ente y secuencia
      begin
         update  GE_PAG_COMERCIOS_DET_TMP set cod_ente = p_cod_ente,
                                              nro_secuencia = v_secuencia,
                                              fec_proceso   = p_fec_hoy;
         if sql%notfound then
          RAISE_APPLICATION_ERROR(-20711,'ERROR. Al actualiza GE_PAG_COMERCIOS_TMP ');
         end if;
      end;


      p_lugar := 'PR_INS_GE_PAG_COMERCIO_DET : Obt_Datos_cuenta';
      --
      FOR r1 in c1 LOOP
         v_cuenta := r1.nro_cuenta;
         v_sueldo := r1.importe;

         if r1.cod_rubro is null and v_cuenta is not null then
             v_mensaje_error := null;
             v_codigo_error := 0;
             --Obtengo el modulo,la modalidad y la oficina de la cuenta
             BEGIN
               SELECT A.COD_MODULO,A.COD_MODALIDAD,A.COD_OFICINA,A.COD_MONEDA
                INTO v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_cod_moneda
                 FROM GE_CUENTAS A
                  WHERE A.NRO_CUENTA = V_CUENTA;
             EXCEPTION
                WHEN OTHERS THEN
                update ge_pag_comercios_det_tmp set cod_proceso=12
                 where rowid = r1.rowid;
                 p_cant_error := 1;
                 v_codigo_error:= 12;
             END;

             IF v_codigo_error <> 12 then
               p_lugar := 'PR_INS_GE_PAG_COMERCIO_DET :PAG_CTA.PR_VER_OPERACION : '||v_cuenta;
               if v_cod_modulo = 3 then
                 begin
                   select estado
                     into v_est_cuenta
                     from ah_cta_vistas
                    where nro_cuenta = v_cuenta;
                 exception
                   when others then
                     v_est_cuenta := 'X';
                 END;
               else
                 begin
                   select estado
                     into v_est_cuenta
                     from cc_cta_corrientes
                    where nro_cuenta = v_cuenta;
                 exception
                   when others then
                     v_est_cuenta := 'X';
                 END;
               end if;

               if v_est_cuenta in ('A','C','T','D','P') then
                  v_des_estado := PAG_CTA.fu_obt_nom_estado(v_cod_modulo,v_cod_modalidad,v_est_cuenta);

                  v_mensaje_error := 'No se puede ACREDITAR a cuenta con estado '||v_des_estado;
                  v_codigo_error := 33;

               end if;
            end if;
         else
           begin
               select q.cod_moneda, 4, 41
                 into v_cod_moneda, v_cod_modulo, v_cod_modalidad
                 from cb_rubros q
                where q.cod_rubro = r1.cod_rubro;
             exception
               when others then
                update ge_pag_comercios_det_tmp set cod_proceso=12
                 where rowid = r1.rowid;
                 p_cant_error := 1;
                 v_codigo_error:= 12;

             end;
         end if;

         /** Jira 2262 - AUTOMATIZACION ENVIO Y RECEPCION DE ARCHIVOS DE BANCARD
         || Validar si existe el rubro si es que está cargado.
         || Si existe el rubro no es error.**/
         if r1.cod_rubro is not null and v_codigo_error = 12 then
            v_codigo_error := 0;
         end if;

         IF nvl(v_codigo_error,0) = 0 THEN
            v_est_movimiento := 'N'; -- Movimiento Normal
         ELSE
            v_est_movimiento := 'E'; -- Movimiento Erróneo
         END IF;

         Update ge_pag_comercios_det_tmp
            set estado        = v_est_movimiento,
                cod_PROCESO   = v_codigo_error,
                cod_modalidad = v_cod_modalidad,
                cod_moneda    = v_cod_moneda,
                cod_modulo    = v_cod_modulo,
                observacion   = v_mensaje_error
          where current of c1;

          if sql%notfound then
             RAISE_APPLICATION_ERROR(-20725,'ERROR. Al actualiza ge_pag_comercios_det_tmp '||sqlerrm);
          end if;

      END LOOP;

      p_lugar := 'PR_INS_GE_PAG_COMERCIO_DET : Validación de totales del detalle';
      FOR d in c_det_cuentas LOOP
        update ge_pag_comercios_det_tmp
           set cod_proceso=13,
               estado = 'P'
         where cod_ente = v_cod_bancard
           and nro_cuenta = d.nro_cuenta;
         p_cant_error := 1;
      END LOOP;
    END;
    BEGIN
     SELECT COUNT(*)
       INTO p_Cant_Error
       FROM ge_pag_comercios_det_tmp
      WHERE cod_ente = p_cod_ente
        AND fec_proceso = p_fec_hoy
        AND nro_secuencia = v_Secuencia
        and cod_proceso <> 0;
   EXCEPTION
       WHEN OTHERS THEN
         p_Cant_Error := 0;
   END;
END;
end pr_ins_ge_pag_com_det;

PROCEDURE LP_OBT_MONTO_PRO
 (P_SECUENCIA IN NUMBER
 ,P_COD_ENTE IN NUMBER
 ,P_CANTCRED IN OUT NUMBER
 ,P_MONTCRED IN OUT NUMBER
 ,P_LUGAR OUT VARCHAR2
 ,P_CTA_PAGO IN VARCHAR2
 ,P_FEC_HOY IN DATE
 )
 IS
------------------------------------------------------------
/* Obtener cant.y monto total de pago de comercio */
begin
  p_lugar := 'Obtener_CantMont_Proc_Total';
  SELECT count(NVL(NRO_TRANSACCION,0)), SUM(NVL(MONTO,0))
    INTO p_CantCred, p_MontCred
    FROM GE_PAG_COMERCIOS
   WHERE COD_ENTE = p_cod_ente
     AND NRO_SECUENCIA = p_Secuencia
     AND TIPO = 'C' ---'D' cambiado a C porque los datos vienen asi  - Delia 31/01/05
     and cod_proceso = 0 --- SIn problemas agregado por ICL 25/01/05
     and trunc(fec_proceso) = trunc(P_FEC_HOY) --- Agregado por ICL solo esa fecha
     AND NRO_CUENTA <> P_CTA_PAGO;
EXCEPTION
   WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(-20090,'ERROR. al monto y cant total proceso '||sqlerrm);
end lp_obt_monto_pro;
PROCEDURE LP_INS_TAB_COM
 (P_COD_ENTE IN NUMBER
 ,P_LUGAR OUT VARCHAR2
 ,P_ERROR OUT VARCHAR2
 )
 IS
------------------------------------------
/* Inserta en la tabla GE_PAG_COMERCIOS */

   w_nro_cuenta   ge_cuentas.nro_cuenta%type;
   v_fecha        ge_pag_comercios.fec_proceso%type:=pae_cnf.FU_OBT_FEC_ACTUAL(5);
   w_cod_rubro    ge_pag_comercios_tmp.cod_rubro%type;

   cursor c_tmp is select t.*, rowid from ge_pag_comercios_tmp t;

    v_monto      number:=0;
    v_monto_tmp  number:=0;
begin
    p_lugar := 'Insert en GE_PAG_COMERCIOS.';

    for reg in c_tmp loop
      w_nro_cuenta  := reg.nro_cuenta ;
      w_cod_rubro   := reg.cod_rubro ;

      p_error := 'N';
          p_lugar := 'Insert en GE_PAG_COMERCIOS';
            begin
              --FB: Se verifica si ya hay registros en ge_pag_comercios no procesados
              --solo se inserta si el total del tmp es <> al total del definitivo
              begin
                select sum(monto)
                  into v_monto
                  from ge_pag_comercios
                 where estado      = 'N'
                   and cod_ente    = reg.cod_ente;
              exception
                when NO_DATA_FOUND then
                     v_monto := 0;
              end;
              begin
                select sum(monto)
                  into v_monto_tmp
                  from ge_pag_comercios_tmp
                 where cod_ente = reg.cod_ente;
              exception
                when NO_DATA_FOUND then
                     v_monto_tmp := 0;
              end;

              if nvl(v_monto,0) <>  nvl(v_monto_tmp,0) or (v_monto + v_monto_tmp) = 0 then
                 insert into ge_pag_comercios
                    (cod_usuario,
                     cod_ente,
                     fec_proceso,
                     nro_secuencia,
                     nro_cuenta,
                     cod_moneda,
                     fec_envio,
                     tipo,
                     monto,
                     estado,
                     cod_proceso,
                     nro_cta_origen,
                     nro_transaccion,
                     cod_modulo,
                     cod_modalidad,
                     fec_proceso_real,
                     cod_rubro,
                     cod_ofi_rubro,
                     nro_orden)
                 select user,
                        cod_ente,
                        trunc(v_fecha),
                        nro_secuencia,
                        nro_cuenta,
                        cod_moneda,
                        fec_envio,
                        decode(tipo,'1','D','C'),
                        monto,
                        estado,
                        cod_proceso,
                        nro_cta_origen,
                        nro_transaccion,
                        cod_modulo,
                        cod_modalidad,
                        fec_proceso_real,
                        cod_rubro,
                        cod_ofi_rubro,
                        s_nro_ord_pago.nextval
                   from ge_pag_comercios_tmp
                  where rowid = reg.rowid;
              end if;
              --
             p_lugar := to_char(v_monto)||'Insert en GE_PAG_COMERCIOS';
            exception
               WHEN OTHERS THEN
               P_ERROR :='S';
               --RAISE_APPLICATION_ERROR(-20098,'ERROR. ' || 'Existen datos ya procesados. Verificar Cuenta: ' || reg.nro_cuenta || ' Monto: ' || reg.monto );
               RAISE_APPLICATION_ERROR(-20098,'ERROR. Cuenta: '||reg.nro_cuenta||', Monto: '||reg.monto||'Msj: '||sqlerrm );
            end;

    end loop;
/*
exception
   WHEN OTHERS THEN
   P_ERROR :='S';
   RAISE_APPLICATION_ERROR(-20099,'ERROR.... Unknown' );*/
end lp_ins_tab_com;
PROCEDURE LP_INS_TAB_COM_DET
 (P_COD_ENTE IN NUMBER
 ,P_LUGAR OUT VARCHAR2
 ,P_ERROR OUT VARCHAR2
 )
 IS
------------------------------------------
/* Inserta en la tabla GE_PAG_COMERCIOS_DET */

   w_nro_cuenta   ge_cuentas.nro_cuenta%type;
   v_fecha        ge_pag_comercios.fec_proceso%type:=pae_cnf.FU_OBT_FEC_ACTUAL(5);

   cursor c_tmp is select t.*, rowid from ge_pag_comercios_det_tmp t;

    v_monto      number:=0;
    v_monto_tmp  number:=0;
begin
    p_lugar := 'Insert en GE_PAG_COMERCIOS_DET.';
    --FB: Se verifica si ya hay registros en ge_pag_comercios no procesados
    --solo se inserta si el total del tmp es <> al total del definitivo
    begin
      select sum(importe)
        into v_monto
        from ge_pag_comercios_det
       where estado      = 'N'
         and cod_ente    = p_cod_ente;
    exception
      when NO_DATA_FOUND then
        v_monto := 0;
    end;
    begin
      select sum(importe)
        into v_monto_tmp
        from ge_pag_comercios_det_tmp
       where cod_ente = p_cod_ente;
    exception
      when NO_DATA_FOUND then
        v_monto_tmp := 0;
    end;

    if nvl(v_monto,0) <>  nvl(v_monto_tmp,0) or (v_monto + v_monto_tmp) = 0 then
      for reg in c_tmp loop
        w_nro_cuenta  := reg.nro_cuenta ;
        p_error := 'N';

        begin
          p_lugar := 'Insert en GE_PAG_COMERCIOS_DET';
                 insert into ge_pag_comercios_det
                    (cod_usuario,
                     cod_ente,
                     nro_resumen,
                     fec_proceso,
                     nro_secuencia,
                     cod_modulo,
                     cod_modalidad,
                     nro_cuenta,
                     cod_moneda,
                     fec_envio,
                     importe,
                     estado,
                     cod_procesadora,
                     nro_cta_origen,
                     cod_proceso,
                     nom_ente,
                     raz_soc_ente,
                     observacion,
                     cod_ent_pag_com,
                     fec_pro_real,
                     cod_rubro)
                 select user,
                        cod_ente,
                        nro_resumen,
                        v_fecha,
                        nro_secuencia,
                        cod_modulo,
                        cod_modalidad,
                        nro_cuenta,
                        cod_moneda,
                        fec_envio,
                        importe,
                        estado,
	                      cod_procesadora,
                        nro_cta_origen,
                        cod_proceso,
                        nom_ente,
                        raz_soc_ente,
                        observacion,
                        cod_ent_pag_com,
                        fec_pro_real,
                        cod_rubro
                   from ge_pag_comercios_det_tmp
                  where rowid = reg.rowid;
              --
             p_lugar := to_char(v_monto)||'Insert en GE_PAG_COMERCIOS_DET';
            exception
               WHEN OTHERS THEN
               P_ERROR :='S';
               --RAISE_APPLICATION_ERROR(-20098,'ERROR. ' || 'Existen datos ya procesados. Verificar Cuenta: ' || reg.nro_cuenta || ' Monto: ' || reg.monto );
               RAISE_APPLICATION_ERROR(-20098,'ERROR al insertar el detalle. Cuenta: '||reg.nro_cuenta||', Monto: '||reg.importe||'Msj: '||sqlerrm );
            end;
        end loop;
   end if;
end lp_ins_tab_com_det;

PROCEDURE PR_OBT_DATOS_EMPRE
 (P_EMPRESA IN NUMBER
 ,P_DESCRIP IN OUT VARCHAR2
 ,P_CTADBSU IN OUT VARCHAR2
 ,P_TRANPDB IN OUT NUMBER
 ,P_CDTASAS IN OUT NUMBER
 ,P_CDTRIVA IN OUT NUMBER
 ,P_CDTRCOM IN OUT NUMBER
 ,P_LUGAR OUT VARCHAR2
 ,P_REFEREN IN OUT VARCHAR2
 ,P_BANCARD OUT VARCHAR2
 )
 IS
 v_param_obliga varchar2(1):= 'N';
-----------------------------------
 /* Obtener datos de la empresa */
begin
 p_lugar := 'Obt_Datos_Empresa';
  SELECT descripcion
    INTO p_descrip
    FROM GE_ENTES
   WHERE cod_ente = p_empresa;
   ------------------------------------------
 -- Se debe obtener los demás parametros...
   ------------------------------------------
  v_param_obliga := fug_obt_parentes(p_empresa, 'PARAM_OBLIGATORIO');
  p_ctadbsu := fug_obt_parentes(p_empresa, 'NRO_CTA_DEB_COMERCIO');
  IF p_ctadbsu IS NULL AND fug_obt_parentes(p_empresa, 'COD_RUB_COMERCIO') IS NULL THEN
   RAISE_APPLICATION_ERROR(-20300,'ATENCION. La empresa no posee Cuenta de Débito. Verifique!!!');
  END IF;
  p_tranpdb := fug_obt_parentes(p_empresa, 'TRA_PAD_DEBITO_COM');
  if p_tranpdb IS NULL THEN
   RAISE_APPLICATION_ERROR(-20310,'ATENCION. La empresa no posee Transacción Padre de Débito. Verifique!!!');
  end if;
  p_cdtasas := fug_obt_parentes(p_empresa, 'COD_TASA_COM');
  if p_cdtasas IS NULL and v_param_obliga = 'S' then
   RAISE_APPLICATION_ERROR(-20320,'ATENCION. La empresa no posee Tasa. Verifique!!!');
  end if;
  p_referen := fug_obt_parentes(p_empresa, 'REFERENCIA_TXT');
  if p_referen IS NULL then
   RAISE_APPLICATION_ERROR(-20320,'ATENCION. La empresa no posee Referencia . Verifique!!!');
  end if;
  p_cdtriva := fug_obt_parentes(p_empresa, 'COD_TRA_IVA_COM');
  if p_cdtriva IS NULL and v_param_obliga = 'S' then
   RAISE_APPLICATION_ERROR(-20330,'ATENCION. La empresa no posee transaccion de IVA. Verifique!!!');
  end if;
  p_cdtrcom := fug_obt_parentes(p_empresa, 'COD_TRA_COMISION_COM');
  if p_cdtrcom is null and v_param_obliga = 'S' then
   RAISE_APPLICATION_ERROR(-20340,'ATENCION. La empresa no posee transaccion de Comision. Verifique!!!');
  end if;
  p_bancard := fug_obt_parentes(p_empresa, 'CRE_COM_BANCARD');
  if p_bancard is null then
   P_BANCARD := 'N';
  end if;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20400,'Empresa Inexistente... Verifique.'||sqlerrm);
  WHEN TOO_MANY_ROWS THEN
   RAISE_APPLICATION_ERROR(-20450,'Empresa Duplicada... AVISE AL ADMINISTRADOR.'||sqlerrm);
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(-20460,'Error en pr_obt_datos_empresa '||sqlerrm);
end pr_obt_datos_empre;

PROCEDURE PR_ACT_NRO_CUENTAS(P_COD_ENTE IN NUMBER
                            ,P_ERROR OUT VARCHAR2) IS
  v_nro_cuenta        ge_pag_comercios.nro_cuenta%type;
  v_tipo              varchar2(1);
  v_cod_rubro         ge_pag_comercios.cod_rubro%type;
  v_ofi_rubro         ba_oficinas.cod_oficina%type;

BEGIN
      --Eliminar Registros con Monto Cero
      delete from ge_pag_comercios_tmp p where nvl(p.monto,0) = 0;

      p_error := 'N';
      --Obtener Nro. de Cuenta Interno
      for k in (select c.cod_ente,
                       c.nro_cta_origen,
                       c.rowid registro
                  from ge_pag_comercios_tmp c
                 where c.nro_cta_origen is not null
                   and c.nro_cuenta is null
                   and c.cod_ente = p_cod_ente) loop
           v_nro_cuenta := null;
           --Buscar Número de Cuenta a partir de la Referencia
           begin
             select c.nro_cuenta,c.cod_rubro,c.tipo,c.cod_ofi_rubro
               into v_nro_cuenta,v_cod_rubro,v_tipo,v_ofi_rubro
               from ge_pag_com_cuentas c
              where c.nro_referencia = k.nro_cta_origen
                and c.cod_ente = k.cod_ente;

             update ge_pag_comercios_tmp z
                set z.nro_cuenta = v_nro_cuenta,
                    z.cod_rubro = v_cod_rubro,
                    z.cod_ofi_rubro = v_ofi_rubro
              where z.rowid = k.registro;
           exception
             when no_data_found then
               begin
                 select c.nro_cuenta,c.cod_rubro,c.tipo,c.cod_ofi_rubro
                   into v_nro_cuenta,v_cod_rubro,v_tipo,v_ofi_rubro
                   from ge_pag_com_cuentas c
                  where to_number(c.nro_referencia) = to_number(k.nro_cta_origen)
                    and c.cod_ente = k.cod_ente;

                 update ge_pag_comercios_tmp z
                    set z.nro_cuenta = v_nro_cuenta,
                        z.cod_rubro = v_cod_rubro,
                        z.cod_ofi_rubro = v_ofi_rubro
                  where z.rowid = k.registro;
               exception
                 when others then
                   update ge_pag_comercios_tmp x
                      set x.cod_proceso = 12
                    where x.rowid = k.registro;
                    p_error := 'S';
               end;
           end;
           --
      end loop;
END PR_ACT_NRO_CUENTAS;

PROCEDURE PR_ACT_NRO_CUENTAS_DET(P_COD_ENTE IN NUMBER
                            ,P_ERROR OUT VARCHAR2) IS
  v_nro_cuenta        ge_pag_comercios.nro_cuenta%type;
  v_tipo              varchar2(1);
  v_cod_rubro         ge_pag_comercios.cod_rubro%type;
  v_ofi_rubro         ba_oficinas.cod_oficina%type;

BEGIN
      --Eliminar Registros con Monto Cero
      delete from ge_pag_comercios_det_tmp p where nvl(p.importe, 0) = 0;

      p_error := 'N';
      --Obtener Nro. de Cuenta Interno
      for k in (select c.cod_ente,
                       c.nro_cta_origen,
                       c.rowid registro
                  from ge_pag_comercios_det_tmp c
                 where c.nro_cta_origen is not null
                   and c.nro_cuenta is null
                   and c.cod_ente = p_cod_ente) loop
           v_nro_cuenta := null;
           --Buscar Número de Cuenta a partir de la Referencia
           begin
             select c.nro_cuenta,c.cod_rubro,c.tipo,c.cod_ofi_rubro
               into v_nro_cuenta,v_cod_rubro,v_tipo,v_ofi_rubro
               from ge_pag_com_cuentas c
              where c.nro_referencia = lpad(to_char(k.nro_cta_origen),11, '0')
                and c.cod_ente = k.cod_ente;

             update ge_pag_comercios_det_tmp z
                set z.nro_cuenta = v_nro_cuenta,
                    z.cod_rubro = v_cod_rubro
              where z.rowid = k.registro;
           exception
             when no_data_found then
               begin
                 select c.nro_cuenta,c.cod_rubro,c.tipo
                   into v_nro_cuenta,v_cod_rubro,v_tipo
                   from ge_pag_com_cuentas c
                  where to_number(c.nro_referencia) = to_number(k.nro_cta_origen)
                    and c.cod_ente = k.cod_ente;

                 update ge_pag_comercios_det_tmp z
                    set z.nro_cuenta = v_nro_cuenta,
                        z.cod_rubro = v_cod_rubro
                  where z.rowid = k.registro;
               exception
                 when others then
                   update ge_pag_comercios_det_tmp x
                      set x.cod_proceso = 12
                    where x.rowid = k.registro;
                    p_error := 'S';
               end;
           end;
           --
      end loop;
END PR_ACT_NRO_CUENTAS_DET;

FUNCTION FU_OBT_CTA_COMERCIO(P_FORMATO IN VARCHAR2,
                             P_CUENTA IN VARCHAR2) RETURN VARCHAR2 IS
   v_cuenta ge_cuentas.nro_cuenta%type;
   --v_count  number;
   v_ente   number;
BEGIN

  if p_formato in ('PAG_COM_PANAL','PAG_COM_CABAL','PAG_COM_BEPSA') then

    --Buscar Código de Ente
    select b.cod_ente
      into v_ente
      from ge_par_entes b
     where b.parametro = 'REFERENCIA_TXT'
       and b.val_parametro = p_formato;

    --Buscar en la tabla de Referencia
    begin
       select c.nro_cuenta
         into v_cuenta
         from ge_pag_com_cuentas c
        where c.nro_referencia = p_cuenta
          and c.cod_ente = v_ente;
     exception
       when no_data_found then
         begin
           select c.nro_cuenta
             into v_cuenta
             from ge_pag_com_cuentas c
            where to_number(c.nro_referencia) = to_number(p_cuenta)
              and c.cod_ente = v_ente;
         exception
           when no_data_found then
             null;
         end;
     end;

     if v_cuenta is null then
        if substr(p_cuenta,3,6) in('210100','215000') then
           v_cuenta := substr(p_cuenta,1,2)||'01'||substr(p_cuenta,9,6);
        elsif substr(p_cuenta,3,6) in('210500','215500') then
           v_cuenta := substr(p_cuenta,1,2)||'02'||substr(p_cuenta,9,6);
        else
           v_cuenta := substr(p_cuenta,1,4)||substr(p_cuenta,9,6);
        End if;
     end if;
  end if;

  return v_cuenta;

EXCEPTION
  WHEN OTHERS THEN
    RETURN P_CUENTA;
END FU_OBT_CTA_COMERCIO;

FUNCTION FU_OBT_FEC_ENVIO (P_FOR_ARCHIVO IN VARCHAR2,
                           P_FOR_FECHA IN VARCHAR2,
                           P_REGISTRO IN VARCHAR2) RETURN DATE IS
  v_fecha date;
BEGIN

  if p_for_archivo = 'PAG_COM_CABAL' then
    if substr(p_registro,1,1) = 'H' then
      v_fecha := to_date(substr(p_registro,65,8),p_for_fecha);
    elsif substr(p_registro,1,1) = 'D' then
      v_fecha := to_date(substr(p_registro,57,8),p_for_fecha);
    end if;
  end if;

  return v_fecha;

END FU_OBT_FEC_ENVIO;

PROCEDURE PR_INS_CTA_DEBITO(P_COD_ENTE IN NUMBER,
                            P_CTA_DEBITO IN VARCHAR2,
                            P_ERROR OUT VARCHAR2) IS

  v_cod_rubro          ge_pag_comercios.cod_rubro%type;
  v_nro_cuenta        ge_pag_comercios.nro_cuenta%type := null;
  v_existe_rubro      varchar2(1):= 'N';

  v_cta               ge_pag_comercios.nro_cuenta%type := null;
  v_tot_credito       ge_cuentas.sal_contable%type;
  v_tot_debito        ge_cuentas.sal_contable%type;
  v_fec_proceso       date;
  v_fec_envio         date;
  v_fec_actual        date;

BEGIN

    --Verificar si el Débito es contra un Rubro Contable
    v_cod_rubro := fug_obt_parentes(p_cod_ente,'COD_RUB_COMERCIO');

    --Insertar la Cuenta en GE_PAG_COMERCIOS_TMP, si no vino en el TXT
    if p_cod_ente != v_cod_bancard then --Bancard no envia las cuentas de Debito
      begin
        select nro_cuenta
          into v_cta
          from ge_pag_comercios_tmp
         --where nro_cuenta = p_cta_debito
         --  and tipo = 1;
         where tipo = 1;
      exception
        when others then
          begin
            select 'S'
              into v_existe_rubro
              from ge_pag_comercios_tmp
             where cod_rubro = v_cod_rubro
               and tipo = 1;
          exception
            when others then
              v_existe_rubro := 'N';
          end;
      end;

       if v_cta is null and v_existe_rubro='N' then
          --Buscar el Monto Total Sumando los Creditos
          begin
             select sum(nvl(monto,0))
               into v_tot_credito
               from ge_pag_comercios_tmp
              where tipo = 2;
          exception
             when others then
             p_error := 'Error al buscar totales credito cta.de pago'||sqlerrm;
             return;
          end;

          if v_tot_credito > 0 then
             begin
                select max(fec_envio)
                  into v_fec_envio
                  from ge_pag_comercios_tmp t
                 where t.cod_ente = p_cod_ente;

                select max(fec_proceso_real)
                  into v_fec_proceso
                  from ge_pag_comercios_tmp x;

                if v_cod_rubro is not null then
                   v_nro_cuenta := null;
                else
                   v_nro_cuenta := p_cta_debito;
                end if;

                insert into ge_pag_comercios_tmp
                 (nro_cuenta,
                  nro_cta_origen, 
                  monto,
                  tipo,
                  fec_envio,
                  cod_ente,
                  fec_proceso_real,
                  cod_rubro)
               values
                 (v_nro_cuenta,
                  v_nro_cuenta,
                  v_tot_credito,
                  '1',
                  nvl(v_fec_envio, v_fec_actual),
                  p_cod_ente,
                  v_fec_proceso,
                  v_cod_rubro);
             exception
                when others then
                   p_error := 'Error al insertar en tmp cta de debito : '||sqlerrm;
                   return;
             end;
          end if;

          --Buscar Monto Total a Acreditar Sumando Debitos
          begin
             select sum(nvl(monto,0))
               into v_tot_debito
               from ge_pag_comercios_tmp
              where tipo = 1
                and nro_cuenta <> p_cta_debito
                and cod_rubro <> nvl(v_cod_rubro,'x');
          exception
             when others then
             p_error := 'Error al buscar totales debitos cta.de pago'||sqlerrm;
             return;
          end;

          if v_tot_debito > 0 then
             begin
                select max(fec_envio)
                  into v_fec_envio
                  from ge_pag_comercios_tmp t;

                select max(fec_proceso_real)
                  into v_fec_proceso
                  from ge_pag_comercios_tmp x;

                if v_cod_rubro is not null then
                   v_nro_cuenta := null;
                else
                   v_nro_cuenta := p_cta_debito;
                end if;

                insert into ge_pag_comercios_tmp
                   (nro_cuenta,
                    monto,
                    tipo,
                    fec_envio,
                    cod_ente,
                    fec_proceso_real,
                    cod_rubro)
                values
                   (v_nro_cuenta,
                    v_tot_debito,
                    '2',
                    nvl(v_fec_envio, v_fec_actual),
                    p_cod_ente,
                    v_fec_proceso,
                    v_cod_rubro);
             exception
                when others then
                p_error := 'Error al insertar en tmp cta de debito '||sqlerrm;
                return;
             end;
          end if;
       end if;
    end if;

END PR_INS_CTA_DEBITO;

end PAG_COM;
/
