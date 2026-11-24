CREATE OR REPLACE PROCEDURE IT.PRA_LIB_RET_CHEQUES
 (P_ORIGEN IN VARCHAR2 DEFAULT NULL, --L=LOCAL, E=EXTERIOR
  P_CHEQUE IN NUMBER DEFAULT NULL
 ,P_BANCO IN NUMBER DEFAULT NULL
 ,P_NRO_BOLETA IN NUMBER DEFAULT NULL
 ,P_NRO_CUENTA IN VARCHAR2 DEFAULT NULL
 ,P_FECHA IN DATE DEFAULT NULL
 ,P_LIB_POSTERIOR IN VARCHAR2 DEFAULT null
 ,P_HORA IN VARCHAR2 DEFAULT NULL 
 )
 IS
 -------------------------------------------------------------------------
 /*Proceso para liberar retenciones por cheque(C/O/B):
   --Libera el cheque seleccionado, pasa el estado de este a "L"(LIBERADO) y actualiza
   --el saldo retenido en AH_RETENCIONES y en el MAESTRO segun la modalidad (CC_CTA_CORRIENTES,AH_CTA_VISTAS,ETC).

   Secuencia:
     --Traer datos del cheque y retención
     --Actualizar Saldo Retenido de la Boleta (AH_RETENCIONES)
     --Actualizar el Saldo Retenido en el Maestro
     --Marcar como LIBERADA la boleta si corresponde (si SAL_RETENIDO=0)
     --Marcar el Cheque como LIBERADO
     --Insertar movimiento por la Liberación
 */
 -------------------------------------------------------------------------
 ---variables
   v_can_che_exonerado      NUMBER DEFAULT 0;
   v_can_che                NUMBER := 0;
   v_can_cheques            NUMBER := 0;
   v_can_che_mes_pl         NUMBER := 0;
   v_can_che_mes_pe         NUMBER := 0;
   v_can_che_cobrar         NUMBER := 0;
   v_tot_cheques            NUMBER := 0; 
   v_fec_inicial     DATE DEFAULT pag_cal.fu_obt_fec_pri_dia_mes_habil(4);   
 --Datos de la Retención (de AH_RETENCIONES y CC_CHE_ENVIADOS)
 TYPE R_RETENCION IS RECORD
 (nro_documento ah_retenciones.nro_documento%type,
  fec_inicio ah_retenciones.fec_inicio%type,
  cod_modulo ah_retenciones.cod_modulo%type,
  cod_modalidad ah_retenciones.cod_modalidad%type,
  cod_moneda ah_retenciones.cod_moneda%type,
  cod_oficina ah_retenciones.cod_oficina%type,
  cod_ofi_origen ah_retenciones.cod_ofi_origen%type,
  cod_retencion ah_retenciones.cod_retencion%type,
  nro_cheque cc_che_enviados.nro_cheque%type,
  cod_banco cc_che_enviados.cod_banco%type,
  nro_cuenta cc_che_enviados.nro_cuenta%type,
  fecha cc_che_enviados.fecha%type,
  monto cc_che_enviados.monto%type,
  fila_cheque  rowid,
  fila_retencion rowid
  );

  --Declaración de Variables
  rv_retencion r_retencion;
  r_gmovi ge_movimientos%rowtype;
  v_encontro varchar2(1):='N';
  v_cod_moneda ah_cta_vistas.cod_moneda%type;
  v_hora ge_movimientos.hora%type;
  v_fec_actual date;
  v_mensaje varchar2(250);
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
  v_cod_mod_padre ba_modulos.cod_modulo%type;
  v_cod_mad_padre varchar2(240);
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  v_cod_usuario ba_usuarios.cod_usuario%type;
  v_tra_cargo ge_transacciones.cod_transaccion%type := 0;
  v_nro_documento ah_retenciones.nro_documento%type;
  v_sal_retenido ah_retenciones.sal_retenido%type;
  v_gen_cargo    varchar2(1) := 'N';
  v_ret         NUMBER(3) := 0;
  v_nro_cheque    ge_che_custodias.nro_cheque%type; 

  --PROCEDIMIENTOS LOCALES
  /* Actualizar el saldo retenido en AH_CTA_VISTAS. */
  PROCEDURE LP_ACT_SAL_RET_VISTA IS
  cursor c_ah_cta_vistas is
  select cod_moneda
    from ah_cta_vistas
   where nro_cuenta = rv_retencion.nro_cuenta
     for update of sal_retenido;
  BEGIN
     if c_ah_cta_vistas%isopen then
        close c_ah_cta_vistas;
     end if;
     open c_ah_cta_vistas;
     v_encontro := 'N';
     fetch c_ah_cta_vistas into v_cod_moneda;
     if c_ah_cta_vistas%found then
        v_encontro := 'S';
        update ah_cta_vistas
           set sal_retenido = nvl(sal_retenido,0) - nvl(rv_retencion.monto,0),
               fec_ult_movimiento = v_fec_actual,
               hor_ult_movimiento = v_hora
         where current of c_ah_cta_vistas;
     else
        v_mensaje := ' No se encontro cuenta ' || rv_retencion.nro_cuenta || ' en AH_CTA_VISTAS...';
     end if;
     close c_ah_cta_vistas;
  END;

  /* Actualiza el saldo retenido en AH_CTA_PLAZOS. */
  PROCEDURE lp_act_sal_ret_plazo is
  cursor c_ah_cta_plazos is
  select cod_moneda
    from ah_cta_plazos
   where nro_cuenta = rv_retencion.nro_cuenta
     for update of sal_retenido;
  BEGIN
     if c_ah_cta_plazos%isopen then
        close c_ah_cta_plazos;
     end if;
     open c_ah_cta_plazos;
     v_encontro := 'N';
     fetch c_ah_cta_plazos into v_cod_moneda;
     if c_ah_cta_plazos%found then
        v_encontro := 'S';
        update ah_cta_plazos
           set sal_retenido = nvl(sal_retenido,0) - nvl(rv_retencion.monto,0),
               fec_ult_movimiento = v_fec_actual,
               hor_ult_movimiento = v_hora
         where current of c_ah_cta_plazos;
     else
        v_mensaje := ' No se encontro cuenta ' || rv_retencion.nro_cuenta || ' en AH_CTA_PLAZOS...';
     end if;
     close c_ah_cta_plazos;
  END;

  /* Actualiza el saldo retenido en CC_CTA_CORRIENTES. */
  PROCEDURE LP_ACT_SAL_RET_CTE IS
  cursor c_cc_cta_corrientes is
     select cod_moneda
       from cc_cta_corrientes
      where nro_cuenta = rv_retencion.nro_cuenta
        for update of sal_retenido;
  BEGIN
     if c_cc_cta_corrientes%isopen then
        close c_cc_cta_corrientes;
     end if;
     open c_cc_cta_corrientes;
     v_encontro := 'N';
     fetch c_cc_cta_corrientes into v_cod_moneda;
     if c_cc_cta_corrientes%found then
        v_encontro := 'S';
        update cc_cta_corrientes
           set sal_retenido = nvl(sal_retenido,0) - nvl(rv_retencion.monto,0),
           fec_ult_movimiento = v_fec_actual,
           hor_ult_movimiento = v_hora
         where current of c_cc_cta_corrientes;
     else
        v_mensaje := ' No se encontro cuenta ' || rv_retencion.NRO_CUENTA || ' en CC_CTA_CORRIENTES...';
     end if;
     close c_cc_cta_corrientes;
  END;

  /* Actualiza el saldo retenido en CC_CTA_BANCARIAS. */
  PROCEDURE LP_ACT_SAL_RET_BAN IS
  cursor c_cc_cta_bancarias is
     select cod_moneda
       from cc_cta_bancarias
      where nro_cuenta = rv_retencion.nro_cuenta
        for update of sal_retenido;
  BEGIN
     if c_cc_cta_bancarias%isopen then
        close c_cc_cta_bancarias;
     end if;
     open c_cc_cta_bancarias;

     fetch c_cc_cta_bancarias into v_cod_moneda;
     if c_cc_cta_bancarias%found then

        update cc_cta_bancarias
           set sal_retenido = nvl(sal_retenido,0) - nvl(rv_retencion.monto,0),
           fec_ult_movimiento = v_fec_actual,
           hor_ult_movimiento = v_hora
         where current of c_cc_cta_bancarias;
     else
        v_mensaje := ' No se encontro cuenta ' || rv_retencion.NRO_CUENTA|| ' en C_CC_CTA_BANCARIAS...';
     end if;
     close c_cc_cta_bancarias;
  END;

  /* Actualiza el saldo retenido en AH_RETENCIONES */
  PROCEDURE LP_ACT_SAL_RET_BOLETA IS
  cursor c_ah_retenciones is
     select nro_documento
       from ah_retenciones
      where rowid = rv_retencion.fila_retencion
        for update of sal_retenido;
  BEGIN
     if c_ah_retenciones%isopen then
        close c_ah_retenciones;
     end if;
     open c_ah_retenciones;
     v_encontro := 'N';
     fetch c_ah_retenciones into v_nro_documento;
     if c_ah_retenciones%found then
        v_encontro := 'S';
        update ah_retenciones
           set sal_retenido = nvl(sal_retenido,0) - nvl(rv_retencion.monto,0)
         where current of c_ah_retenciones;
     else
        v_mensaje := ' No se encontro Nro.Documento ' || rv_retencion.nro_documento|| ' en C_AH_RETENCIONES...';
     end if;
     close c_ah_retenciones;
  END;

  /* Actualiza el estado en AH_RETENCIONES */
  PROCEDURE LP_ACT_EST_BOLETA IS
  cursor c_ah_retenciones is
     select nro_documento, sal_retenido
       from ah_retenciones
      where rowid = rv_retencion.fila_retencion
        for update of liberado;
  BEGIN
     if c_ah_retenciones%isopen then
        close c_ah_retenciones;
     end if;
     open c_ah_retenciones;
     fetch c_ah_retenciones into v_nro_documento, v_sal_retenido;
     if c_ah_retenciones%found then
        if v_sal_retenido = 0 then --Marco como liberado si SAL_RETENIDO = 0
          update ah_retenciones
             set liberado = 'S'
           where current of c_ah_retenciones;
        end if;
     else
        v_mensaje := ' No se encontro Nro.Documento ' || rv_retencion.nro_documento|| ' en C_AH_RETENCIONES...';
     end if;
     close c_ah_retenciones;
  END;

  /* Actualiza el estado en CC_CHE_ENVIADOS/GE_CHE_EXTERIOR */
  PROCEDURE LP_ACT_EST_CHEQUE IS

  BEGIN
     if p_origen='L' then
        update cc_che_enviados set liberado = 'S' where rowid = rv_retencion.fila_cheque;
     else
        update ge_che_exterior set liberado = 'S' where rowid = rv_retencion.fila_cheque;
     end if;
  END;
PROCEDURE pr_can_chq_exentos
 (p_cod_tasa           in ge_tasas.cod_tasa%type
  ,p_cod_modulo        in ge_cuentas.cod_modulo%type
  ,p_cod_modalidad     in ge_cuentas.cod_modalidad%type
  ,p_cod_sub_modalidad in ge_cuentas.cod_sub_modalidad%type
  ,p_cod_oficina       in ge_cuentas.cod_oficina%type
  ,p_cod_moneda        in ge_cuentas.cod_moneda%type
  ,p_fecha             in date
  ,p_cantidad          out ge_tas_fechas.val_tasa%type
 )
 IS
BEGIN
  BEGIN
    SELECT val_tasa
      INTO p_cantidad
      FROM ge_tas_fechas a
     WHERE cod_modulo = p_cod_modulo
       AND nvl(cod_modalidad,-1) = nvl(p_cod_modalidad,-1)
       AND nvl(cod_sub_modalidad,-1) = nvl(p_cod_sub_modalidad,-1)
       AND nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
       AND nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
       AND cod_tasa = p_cod_tasa
       AND fec_vigencia =(SELECT MAX(fec_vigencia)
                            FROM ge_tas_fechas b
                           WHERE b.cod_modulo        = a.cod_modulo
                             AND b.cod_modalidad     = a.cod_modalidad
                             AND nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
                             AND nvl(b.cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
                             AND nvl(b.cod_moneda,nvl(p_cod_moneda,'x'))  = nvl(p_cod_moneda,'x')
                             AND cod_tasa = p_cod_tasa
                             AND fec_vigencia <= p_Fecha);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_cantidad := 0;
    WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20003,SQLERRM||' Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                               ' - para '||p_cod_moneda||' '||p_Fecha);
  END;
END;

-----**********************************-----
-----    EMPIEZA EL BLOQUE PRINCIPAL   -----
-----**********************************-----
BEGIN

   --Traer Datos del cheque a liberar y de la Retención
   if p_origen = 'L' then --Plaza Local
     select a.nro_documento,a.fec_inicio,a.cod_modulo,a.cod_modalidad,
            a.cod_moneda,a.cod_oficina,c.cod_retencion,c.nro_cheque,
            c.cod_banco,c.nro_cuenta,c.fecha,c.monto,c.rowid,a.rowid
       into rv_retencion.nro_documento,rv_retencion.fec_inicio,rv_retencion.cod_modulo,rv_retencion.cod_modalidad,
            rv_retencion.cod_moneda,rv_retencion.cod_oficina,rv_retencion.cod_retencion,rv_retencion.nro_cheque,
            rv_retencion.cod_banco, rv_retencion.nro_cuenta,rv_retencion.fecha,rv_retencion.monto,rv_retencion.fila_cheque,rv_retencion.fila_retencion
       from cc_che_enviados c, ah_retenciones a
      where c.nro_boleta = a.nro_documento
        and c.cod_retencion = a.cod_retencion
        and c.nro_cuenta = a.nro_cuenta
        and a.liberado = 'N'
        and c.cod_banco = p_banco
        and c.nro_cheque = p_cheque
        and c.fecha = p_fecha
        and c.nro_boleta = p_nro_boleta
        and c.nro_cuenta = p_nro_cuenta
        and (c.estado in ('C','D') or c.cod_moneda=pag_gen.FU_OBT_MON_LOCAL) --Confirmados, Devueltos
        and c.liberado = 'N'
        and c.lib_posterior = nvl(p_lib_posterior, c.lib_posterior)
        and c.usu_modificacion = user;
   elsif p_origen = 'E' then --Traer Datos del cheque de GE_CHE_EXTERIOR
     select a.nro_documento,a.fec_inicio,a.cod_modulo,a.cod_modalidad,
            a.cod_moneda,a.cod_oficina,g.cod_retencion,g.nro_cheque,
            g.cod_banco,g.nro_cuenta,g.fecha,g.monto,g.rowid,a.rowid
       into rv_retencion.nro_documento,rv_retencion.fec_inicio,rv_retencion.cod_modulo,rv_retencion.cod_modalidad,
            rv_retencion.cod_moneda,rv_retencion.cod_oficina,rv_retencion.cod_retencion,rv_retencion.nro_cheque,
            rv_retencion.cod_banco, rv_retencion.nro_cuenta,rv_retencion.fecha,rv_retencion.monto,rv_retencion.fila_cheque,rv_retencion.fila_retencion
       from ge_che_exterior g, ah_retenciones a
      where g.nro_boleta = a.nro_documento
        and g.cod_retencion = a.cod_retencion
        and g.nro_cuenta = a.nro_cuenta
        and a.liberado = 'N'
        and g.cod_banco = p_banco
        and g.nro_cheque = p_cheque
        and g.fecha = p_fecha
        and g.nro_boleta = p_nro_boleta
        and g.nro_cuenta = p_nro_cuenta
        and g.estado in ('C','D') --Confirmados, Devueltos
        and g.liberado = 'N'
        and g.lib_posterior = nvl(p_lib_posterior, g.lib_posterior)
        and g.usu_modificacion = user;
   end if;

   v_cod_mod_padre := 3;
   v_cod_mad_padre := 31;
   v_cod_usuario := user;
   v_fec_actual := pag_cal.fu_obt_fec_actual(3);
   
   if p_hora is null then
      v_hora := fug_ini_hora(sysdate,'hh24:mi:ss');
   else
      v_hora := p_hora;  
   end if;
      
   v_nro_secuencia := nvl(pae_cnf.g_nro_secuencia,-999);

   if rv_retencion.cod_retencion = 0 then
      --Cheque ntro. banco
      v_cod_transaccion := 565;
      v_cod_mod_padre := rv_retencion.cod_modulo;
      v_cod_mad_padre := rv_retencion.cod_modalidad;
   else
     if rv_retencion.cod_retencion = 4 then
       --Cheque plaza extranjejera
       v_cod_transaccion := 560;
       v_gen_cargo       := 'S';
     else
       v_cod_transaccion := 515;
       v_gen_cargo       := 'S';
     end if;
   end if;
   v_encontro := 'N';

   if (rv_retencion.cod_modulo = 3 and
       rv_retencion.cod_modalidad IN (31,334)) then
      lp_act_sal_ret_vista;
      -- Actualiza la retención que ya fue liberada
      ---------------------------------------------
      if v_encontro = 'S' then
         lp_act_sal_ret_boleta;
         lp_act_est_boleta;
         --Marcar como liberado el cheque
         lp_act_est_cheque;
      end if;
    elsif (rv_retencion.cod_modulo = 3 and
          rv_retencion.cod_modalidad = 32) then
         lp_act_sal_ret_plazo;
      --Actualiza la retención que ya fue liberada
      ---------------------------------------------
      if v_encontro = 'S' then
         lp_act_sal_ret_boleta;
         lp_act_est_boleta;
         --Marcar como liberado el cheque
         lp_act_est_cheque;
      end if;
   elsif rv_retencion.cod_modalidad = 41 then
      lp_act_sal_ret_cte;
      -- Actualiza la retención que ya fue liberada
      ---------------------------------------------
      if v_encontro = 'S' then
         lp_act_sal_ret_boleta;
         lp_act_est_boleta;
         --Marcar como liberado el cheque
         lp_act_est_cheque;
      end if;
   elsif rv_retencion.cod_modulo = 4 and rv_retencion.cod_modalidad <> 41 then
         /* Ya se libera los de modalidad 42,43, 44, ...*/
         lp_act_sal_ret_ban;
         -- Actualiza la retención que ya fue liberada
         ---------------------------------------------
      if v_encontro = 'S' then
         lp_act_sal_ret_boleta;
         lp_act_est_boleta;
         --Marcar como liberado el cheque
         lp_act_est_cheque;
      end if;
   end if;

   --- Actualiza diario ---
   ------------------------
   if v_encontro = 'S' then
      if v_nro_secuencia > 990 then
         v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
         v_nro_secuencia := -999;
      end if;
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.cod_usuario   := v_cod_usuario;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.cod_modulo    := rv_retencion.cod_modulo;
      r_gmovi.cod_modalidad := rv_retencion.cod_modalidad;
      r_gmovi.cod_oficina   := rv_retencion.cod_oficina;
      if rv_retencion.cod_modulo = 9 then
         r_gmovi.nro_cuenta := null;
      else
         r_gmovi.nro_cuenta := rv_retencion.nro_cuenta;
      end if;
      r_gmovi.cod_moneda    := rv_retencion.cod_moneda;
      r_gmovi.fec_valor     := rv_retencion.fec_inicio;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre := v_cod_transaccion;
      r_gmovi.cod_transaccion := v_cod_transaccion;
      r_gmovi.nro_documento := rv_retencion.nro_documento;
      r_gmovi.monto         := rv_retencion.monto;
      r_gmovi.cod_retencion := rv_retencion.cod_retencion;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := rv_retencion.cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := v_cod_mod_padre;
      r_gmovi.cod_mad_padre := v_cod_mad_padre;

      r_gmovi.cod_banco     := rv_retencion.cod_banco;
      r_gmovi.nro_documento2:= rv_retencion.nro_cheque;

      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      pae_cnf.g_nro_secuencia := v_nro_secuencia;
   END IF;

   --Notificaciones Fase 3
   v_ret := paw_not.fu_che_lib_fondos(rv_retencion.nro_cuenta,rv_retencion.monto,rv_retencion.cod_moneda,null,rv_retencion.fecha);
   
   -- Realizar Cobro de Cargos para CHQ USD si corresponde
   If v_gen_cargo = 'S' and  v_encontro = 'S' then
     if rv_retencion.cod_retencion = 4 then
        v_tra_cargo := 1178;--3,30
     elsif rv_retencion.cod_retencion in (1,2,3,9) then
        v_tra_cargo := 5021;--1,10
     else
        v_tra_cargo := 0;
     end if;
     --DYDMR-6635 - Incidencia SAU - ITGF - Inconveniente Cobro Deposito Cheque
     v_can_che_exonerado := 0;
     pr_can_chq_exentos(303, rv_retencion.cod_modulo, rv_retencion.cod_modalidad,
                        fug_obt_cod_sub_modalidad(rv_retencion.nro_cuenta), rv_retencion.cod_oficina,
                        rv_retencion.cod_moneda, v_fec_actual, v_can_che_exonerado);
     v_can_che := 0;
     IF NOT nvl(v_tra_cargo, 0) = 0 AND
        rv_retencion.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR') and 
        nvl(v_can_che_exonerado,0) > 0 THEN
        pae_cnf.g_nro_secuencia := v_nro_secuencia;
        ---Cantidad de cheques Plaza Extranjera - depositados en el mes
        BEGIN
          SELECT COUNT(*)
            INTO v_can_che_mes_pe
            FROM ah_retenciones b, ge_che_exterior e
           WHERE b.cod_modulo = rv_retencion.Cod_Modulo
             AND b.cod_modalidad = rv_retencion.cod_modalidad
             AND b.nro_cuenta = rv_retencion.Nro_Cuenta
             AND b.cod_ofi_origen = rv_retencion.Cod_Ofi_Origen
             and b.nro_documento = e.nro_boleta
             AND b.nro_cuenta = e.nro_cuenta
             AND b.liberado = 'S'
             AND b.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR') 
             AND b.fec_final >= v_fec_inicial
             AND b.fec_final <= v_fec_actual;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_can_che_mes_pe := 0;
          WHEN OTHERS THEN
            v_can_che_mes_pe := 0;
        END;
            
        ---Cantidad de cheques Plaza Local - depositados en el mes
        BEGIN
          SELECT COUNT(*)
            INTO v_can_che_mes_pl
            FROM ah_retenciones b, cc_che_enviados e
           WHERE b.cod_modulo = rv_retencion.Cod_Modulo
             AND b.cod_modalidad = rv_retencion.cod_modalidad
             AND b.nro_cuenta = rv_retencion.Nro_Cuenta
             AND b.cod_ofi_origen = rv_retencion.Cod_Ofi_Origen
             and b.nro_documento = e.nro_boleta
             AND b.nro_cuenta = e.nro_cuenta
             AND b.liberado = 'S'
             AND b.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR')
             AND b.fec_final >= v_fec_inicial
             AND b.fec_final <= v_fec_actual;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_can_che_mes_pl := 0;
          WHEN OTHERS THEN
            v_can_che_mes_pl := 0;
        END;
    END IF;  
      
     v_can_cheques := 1; ---asignación fija por que el procesamiento es por cada cheque
     ---Calculo de Cantidad de Cheques a Cobrar 
     v_tot_cheques := (v_can_cheques + v_can_che_mes_pl + v_can_che_mes_pe) - v_can_che_exonerado;
         
     If v_tot_cheques > v_can_che_exonerado then
        If (v_can_che_mes_pe + v_can_che_mes_pl) >= v_can_che_exonerado then
           v_can_che_cobrar := v_can_cheques; 
        else  
           v_can_che_cobrar := 0; 
        End if;  
     Else
        v_can_che_cobrar := 0;
     End if;        
     
     if not nvl(v_tra_cargo,0) = 0 and rv_retencion.cod_moneda in (pag_gen.fu_obt_mon_fuerte, 'EUR')
       and not nvl(v_can_che_cobrar,0) = 0 then
        prg_cob_car_che_usd(rv_retencion.nro_cuenta,v_tra_cargo, v_nro_cheque,
                            rv_retencion.nro_documento , v_can_che_cobrar);
     end if;
     v_gen_cargo := 'N';
   End if;
   

END;
/
