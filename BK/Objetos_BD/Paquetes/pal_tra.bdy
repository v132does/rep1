CREATE OR REPLACE PACKAGE BODY IT.PAL_TRA is

--Verificamos si la persona tiene exoneracion por gasto OUR
FUNCTION FU_VER_GTO_EXONERADO(p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
   v_exonerado VARCHAR2(1);
BEGIN
   begin
      SELECT 'S'
        INTO v_exonerado
        FROM ge_tas_fechas a
       WHERE a.cod_tasa = 36
         AND a.cod_persona = p_cod_persona
         AND a.val_extension = 100
         AND a.fec_vigencia = (select max(b.fec_vigencia)
                                 from ge_tas_fechas b
                                where b.cod_tasa = a.cod_tasa
                                  and b.cod_persona = a.cod_persona)
         AND a.fec_vencimiento >= trunc(sysdate);
   exception
      when no_data_found then
         BEGIN
            SELECT 'S'
              INTO v_exonerado
              FROM ge_tas_fechas a
             WHERE a.cod_tasa = 34
               AND a.cod_persona = p_cod_persona
               AND a.val_extension = 100
               AND a.fec_vigencia = (select max(b.fec_vigencia)
                                       from ge_tas_fechas b
                                      where b.cod_tasa = a.cod_tasa
                                        and b.cod_persona = a.cod_persona)
               AND a.fec_vencimiento >= trunc(sysdate);
         EXCEPTION
            WHEN OTHERS THEN
               v_exonerado := 'N';
         END;
      when others then
         v_exonerado := 'N';
   end;
   RETURN v_exonerado;
END;

FUNCTION FU_VAL_CONTRATO(p_cod_persona       IN ba_personas.cod_persona%TYPE,
                         p_cod_mon_debito    IN ba_monedas.cod_moneda%TYPE,
                         p_nro_contrato      IN lc_ope_pendientes.nro_diario%TYPE,
                         p_cto_cod_moneda    OUT ba_monedas.cod_moneda%TYPE,
                         p_cto_mto_cargo2    OUT NUMBER,
                         p_cto_monto         OUT NUMBER,
                         p_cto_tip_operacion OUT lc_tip_operaciones.cod_tip_operacion%TYPE) 
   RETURN NUMBER IS
   v_cod_mon_contrato ba_monedas.cod_moneda%TYPE;
BEGIN
   -- hora invalida
   IF to_char(sysdate,'HH24:MI') NOT BETWEEN
      to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_INICIO', 7, 71),'HH24:MI'),'HH24:MI') AND
      to_char(to_date(fug_obt_pardinamico('HOR_PRE_ESP_FIN', 7, 71),'HH24:MI'),'HH24:MI') THEN
      RETURN -1;
   END IF;

   BEGIN
      SELECT l.cod_moneda, nvl(l.mto_cargo2, 0), nvl(l.monto, 0), l.cod_tip_operacion
        INTO p_cto_cod_moneda, p_cto_mto_cargo2, p_cto_monto, p_cto_tip_operacion
        FROM lc_ope_pendientes l
       WHERE l.nro_diario = p_nro_contrato
         AND l.liquidado = 'N'
         AND l.ope_homebanking = 'S'
         AND l.nro_documento = FUE_OBT_NRO_DOC_PERSONA(p_cod_persona)
         AND trunc(l.fec_operacion) = pag_cal.fu_obt_fec_actual(7);
      -- la moneda debito para este caso debe ser local, sino es arbitraje
      IF nvl(p_cod_mon_debito, 'x') <> pag_gen.fu_obt_mon_local() THEN
         RETURN -3;  
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         -- verificar si no es arbitraje
         SELECT l.cod_moneda, nvl(l.mto_cargo2, 0), nvl(l.monto, 0), l.cod_tip_operacion
           INTO p_cto_cod_moneda, p_cto_mto_cargo2, p_cto_monto, p_cto_tip_operacion
           FROM lc_ope_pen_cambios l
          WHERE l.nro_diario = p_nro_contrato
            AND l.liquidado = 'N'
            AND l.ope_homebanking = 'S'
            -- venta 0hrs, 24hrs y 48hrs para arbitraje
            AND l.cod_tip_operacion IN (44, 442, 443)
            AND trunc(l.fec_operacion) = pag_cal.fu_obt_fec_actual(7);
         -- validamos que exista su contraparte-compra debito en cuenta
         SELECT l.cod_moneda
           INTO v_cod_mon_contrato
           FROM lc_ope_pen_cambios l
          WHERE l.nro_diario = p_nro_contrato
            AND l.liquidado = 'N'
            AND l.ope_homebanking = 'S'
            AND l.cod_tip_operacion = 61
            AND l.nro_documento = FUE_OBT_NRO_DOC_PERSONA(p_cod_persona)
            AND trunc(l.fec_operacion) = pag_cal.fu_obt_fec_actual(7);
         -- compra debito en cuenta debe ser la misma moneda que la cuenta a debitar
         IF v_cod_mon_contrato <> nvl(p_cod_mon_debito, 'x') THEN
            RETURN -3;  
         END IF;
   END;
   RETURN 0;                
EXCEPTION
   WHEN OTHERS THEN
      RETURN -2; -- contrato no existe
END;

PROCEDURE LP_OBT_OPE_CAMBIO(p_cod_mon_debito   IN ba_monedas.cod_moneda%TYPE,
                            p_cod_mon_credito  IN ba_monedas.cod_moneda%TYPE,
                            p_plazo            IN NUMBER,
                            p_can_ope          IN OUT NUMBER,
                            p_cod_tip_ope_vta  IN OUT lc_tip_operaciones.cod_tip_operacion%TYPE,
                            p_cod_tip_ope_cpra IN OUT lc_tip_operaciones.cod_tip_operacion%TYPE,
                            p_tipo             IN OUT VARCHAR2) IS
   v_mon_local ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
BEGIN
   IF p_cod_mon_debito <> p_cod_mon_credito then
      IF p_cod_mon_debito <> v_mon_local THEN  -- arbitraje
         if p_plazo = 0 then
            p_cod_tip_ope_vta := 44; --ARB VENTA TRANSFERENCIA O HORAS
         elsif p_plazo = 1 then
            p_cod_tip_ope_vta := 442; --ARB VENTA TRANSFERENCIA 24 HORAS
         elsif p_plazo=2 then
            p_cod_tip_ope_vta := 443; --ARB VENTA TRANSFERENCIA 48 HORAS
         end if;
         p_cod_tip_ope_cpra := 61; --ARB COMPRA DEBITO EN CUENTA CLIENTE
         p_tipo := 'TTE-MONEXT';
         p_can_ope := 2;
      ELSE  
         if p_plazo = 0 then
            p_cod_tip_ope_vta := 29; --VENTA TRANSFERENCIA O HORAS
         elsif p_plazo = 1 then
            p_cod_tip_ope_vta := 292; --VENTA TRANSFERENCIA 24 HORAS
         elsif p_plazo = 2 then
            p_cod_tip_ope_vta := 293; --VENTA TRANSFERENCIA 48 HORAS
         end if;
         p_can_ope := 1;
         p_cod_tip_ope_cpra := null;
         p_tipo := 'TTE-MONLOC';
      end if;
   ELSE
      --Es un Canje de Divisas
      p_tipo := 'TTE-CANJE';
      IF p_plazo = 0 THEN
         p_cod_tip_ope_vta := 74; --CANJE VENTA DE TRANSFERENCIA - 0 HS
      ELSIF p_plazo = 1 THEN
         p_cod_tip_ope_vta := 742; --CANJE VENTA DE TRANSFERENCIA - 24 HS
      ELSIF p_plazo = 2 THEN
         p_cod_tip_ope_vta := 743; --CANJE VENTA DE TRANSFERENCIA - 48 HS
      END IF;
      p_cod_tip_ope_cpra := 91; --CANJE COMPRA DEBITO CUENTA CLIENTE
   END IF;
END;
   
PROCEDURE PR_INS_MOV_TRA_HB
(p_nro_cuenta       in varchar2 default null,
p_cod_mon_tra       in varchar2,     --Moneda Transferencia
p_plazo             in number,       --Plazo de La Transferencia
p_monto             in number default null, --Monto de la Transferencia
p_nro_prepactada    in number default null, --Nro de Operación Pre-pactada
p_tip_cargo         in varchar2, --'OUR'/'BEN'
p_exonerado         in varchar2, -- 'S'/'N'
p_cotizacion        in number, --Cotización de Moneda de Transferencia
p_cot_contra        in number, --Cotización de Moneda de contra partida
p_es_noc            in varchar2:='N', --Si el movimiento es nocturno o No
p_nro_documento     out number, --Nro de Documento para el Movimiento
p_nro_documento2     out number, --Nro de Documento para el Movimiento
p_respuesta         out number, --Respuesta 0 sino hubo errores, sino Error
p_msj_error         out varchar2
)
/*Procedimiento que inserta movimientos de transferencias enviadas via HB
  A tener en Cuenta:
       ** Si la moneda de la transferencia es diferente al de la cuenta
          y la moneda de la Cta no es en GS, se hace:
         -----Vta. Transferencia (Porque no se maneja Arbitraje)
         - O Horas - 44 Venta transferencia 0 Horas / Déb Cta Cble.
         - 24 Horas - 442 Venta transferencia 24 Horas / Déb Cta Cble.
         - 48 Horas - 443 Venta transferencia 48 Horas / Déb Cta Cble.
         -----Compra Débito en Cta de Cliente
         - 61 Compra Débito en Cta de Cliente / Créd. Cta.Cble.

       ** Si la moneda de la transferencia es diferente al de la cuenta
         y la moneda de la Cta es en GS, se hace:
         -----Venta Transferencia
         - O Horas - 29 Venta transferencia 0 Horas / Déb Cta Cliente.
         - 24 Horas - 292 Venta transferencia 24 Horas / Déb Cta Cliente.
         - 48 Horas - 293 Venta transferencia 48 Horas / Déb Cta Cliente.

       ** Si la moneda de la transferencia es igual al de la cuenta, se hace:
         -----Canje de Divisas
         - O Horas - 74 Canje Venta de transferencias - 0 Horas / 91 Canje Compra Débito Cta Cliente
         - 24 Horas - 742 Canje Venta de transferencias - 24 Horas / 91 Canje Compra Débito Cta Cliente
         - 48 Horas - 743 Canje Venta de transferencias - 48 Horas / 91 Canje Compra Débito Cta Cliente
*/
IS
v_fec_actual        date := pag_cal.fu_obt_fec_actual(9);
v_cod_modalidad     ge_movimientos.cod_modalidad%type;
v_cod_oficina       ge_movimientos.cod_oficina%type;
v_hora              ge_movimientos.hora%type;
v_tot_mon_local     ge_movimientos.monto%type;
v_tot_mon_local_vta ge_movimientos.monto%type;
v_tot_mon_compra    ge_movimientos.monto%type;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_ope_vta   lc_tip_operaciones.cod_tip_operacion%type;
v_cod_tip_ope_cpra  lc_tip_operaciones.cod_tip_operacion%type;
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi             ge_movimientos%rowtype;
v_nro_secuencia     ge_movimientos.nro_secuencia%type :=0;
v_nro_operacion     ge_movimientos.nro_documento%type;
v_nro_operacion2    ge_movimientos.nro_documento%type;
v_nro_ope_compra    ge_movimientos.nro_documento%type;
v_cod_persona       ge_movimientos.cod_persona%type;
v_cta_referencia    ge_movimientos.cod_rubro%type;
v_mto_cargo1        lc_ope_pendientes.mto_cargo1%type;
v_mto_car_1         lc_ope_pendientes.mto_cargo1%type;
v_mto_car_2         lc_ope_pendientes.mto_cargo1%type;
v_mto_cargo2        lc_ope_pendientes.mto_cargo2%type;
v_mto_contra4       lc_ope_pendientes.mto_contra4%type;
v_cta_ref_contra4   lc_ope_pendientes.cta_ref_contra4%type;
v_cta_ref_contra3   lc_ope_pendientes.cta_ref_contra3%type;
v_nro_cuenta        lc_ope_pendientes.nro_cuenta%type;
v_cta_cambios       lc_ope_pendientes.nro_cuenta%type;
v_cod_mod_cta       ge_movimientos.cod_modulo%type default null;
v_cod_moda_cta      ge_movimientos.cod_modalidad%type default null;
v_cod_mon_cta       ge_movimientos.cod_moneda%type default null;
v_cod_moneda        lc_transferencias.cod_moneda%type;
v_monto             lc_transferencias.monto%type;
v_afe_pos_cpra      lc_tip_operaciones.afe_posicion%type;
v_afe_lim_cpra      lc_tip_operaciones.afe_limite%type;
v_caj_cpra          lc_tip_operaciones.caja%type;
v_tip_val_cpra      lc_tip_operaciones.tip_valor%type;
v_mod_ori_cpra      lc_tip_operaciones.cod_mod_origen%type;
v_mad_hij_cpra      lc_tip_operaciones.cod_mad_hijo%type;
v_cod_tip_ope_pre   lc_ope_pendientes.cod_tip_operacion%type;
v_cod_tra_ope_cpra  lc_tip_operaciones.cod_transaccion%type;
v_cod_tra_cargo1    lc_tip_operaciones.cod_tra_cargo1%type;
v_cod_tra_cargo2    lc_tip_operaciones.cod_tra_cargo2%type;
v_cod_tra_cargo3    lc_tip_operaciones.cod_tra_cargo3%type;
v_tip_apl_cpra      lc_tip_ope_oficinas.tip_aplicacion%type;
v_cod_rub_cpra      lc_tip_ope_oficinas.cod_rubro%type;
v_cod_tip_ref_cpra  lc_tip_ope_oficinas.cod_tip_referencia%type;
v_des_ope_cpra      lc_tip_operaciones.descripcion%type;
v_ope_bcp_cpra      lc_tip_operaciones.cod_tip_ope_bcp%type;
v_cot_compra        ge_cotizaciones.val_conversion%type;
v_cot_venta         ge_cotizaciones.val_conversion%type;
v_cod_tasa_ini      ge_movimientos.cod_tasa%type;
v_cod_tasa_ini1     ge_movimientos.cod_tasa%type;
v_des_cargo         ge_transacciones.descripcion%type;
v_afe_pos_vta       lc_tip_operaciones.afe_posicion%type;
v_afe_lim_vta       lc_tip_operaciones.afe_limite%type;
v_caj_vta           lc_tip_operaciones.caja%type;
v_tip_val_vta       lc_tip_operaciones.tip_valor%type;
v_mod_ori_vta       lc_tip_operaciones.cod_mod_origen%type;
v_mad_hij_vta       lc_tip_operaciones.cod_mad_hijo%type;
v_cod_tra_ope_vta   lc_tip_operaciones.cod_transaccion%type;
v_tip_apl_vta       lc_tip_ope_oficinas.tip_aplicacion%type;
v_cod_rub_vta       lc_tip_ope_oficinas.cod_rubro%type;
v_cod_rub_ope       lc_tip_ope_oficinas.cod_rubro%type;
v_cod_tip_ref_vta   lc_tip_ope_oficinas.cod_tip_referencia%type;
v_des_ope_vta       lc_tip_operaciones.descripcion%type;
v_ope_bcp_vta       lc_tip_operaciones.cod_tip_ope_bcp%type;
v_nro_ref_vta       lc_transferencias.nro_referencia%type;
v_nro_ref_cpra      lc_transferencias.nro_referencia%type;
v_mad_operacion     lc_transferencias.cod_modalidad%type;
v_mon_local         ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
v_mon_fuerte        ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
v_cod_ofi_cta       lc_cta_cambios.cod_oficina%type;
v_est_mvto          ge_movimientos.estado%type :='N';
v_tra_impuesto      ge_movimientos.cod_transaccion%type;
v_tra_impuesto1     ge_movimientos.cod_transaccion%type;
v_impuesto          ge_movimientos.monto%type;
v_impuesto1         ge_movimientos.monto%type;
v_mov_impuesto      ge_movimientos.monto%type;
v_mov_impuesto1     ge_movimientos.monto%type;
v_cod_tasa          ge_movimientos.cod_tasa%type;
v_val_tasa          ge_movimientos.val_tasa%type;
v_cod_tasa1         ge_movimientos.cod_tasa%type;
v_val_tasa1         ge_movimientos.val_tasa%type;
v_redondeo_ml       number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,v_mon_local);
v_redondeo_me       number(2):= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,p_cod_mon_tra);
v_equ_venta         ge_movimientos.mto_equ_local%type;
v_nom_cliente       ge_movimientos.concepto%type;
v_can_ope           number(3):=1;
v_cod_usuario       ge_movimientos.cod_usuario%type:=USER; --El usuario con el que se guardará
v_nro_doc_cliente   ba_personas.nro_documento%type;
v_tot_gral          ge_movimientos.monto%type;
v_lugar             varchar2(1000):=null;
v_tipo              varchar2(10);
v_cod_ref_cam_vta   ge_movimientos.cod_ref_cambio%type;
v_cod_ref_cam_cpr   ge_movimientos.cod_ref_cambio%type;
v_est_cta_cam       varchar2(1);
v_cod_ofi_cta_cam   ge_movimientos.cod_oficina%type;
v_lim_utilizado     ge_movimientos.monto%type;
v_cod_retencion     ge_movimientos.cod_retencion%type;
v_fec_fin_retencion ge_movimientos.fec_fin_retencion%type;
v_respuesta         number:=0;
v_es_noc            varchar2(1):=null;
v_nro_ope_prepactada lc_ope_pendientes.nro_operacion%type;
v_cta_referencia_cre lc_ope_pendientes.cta_referencia%type;
v_cod_mon_imp        lc_transferencias.cod_moneda%type; -- DYDMR-4666 Ago/2016
v_imp_personalizado ge_movimientos.monto%type; -- DYDMR-5780 05/2018 NAF
v_imp_personalizado1 ge_movimientos.monto%type;
/* Listado de respuestas posibles
0   'Ok'
-1  'TTE habilitado para Euros y Dólares'
-2  'Monto de Operación debe ser mayor a Cero'
-3  'El tipo de Cargo debe ser OUR o BEN'
-4  'Plazo debe ser 0(0 horas)/1(24 horas)/2(48 horas)'
-5  'Obtener Cta de Débito'
-6  'No se encuentra Op. de Venta Prepactada'
-7  'La Moneda de la Transf. y de la Operac.Prepactada son distintas'
-8  'El Monto de la Transf. y de la Operac.Prepactada son distintos'
-9  'No se encuentra Op. de Compra Prepactada '
-10 'El Nro de Cuenta de la Transf. y de la Operac.Prepactada son distintas'
-11 'Al Obt.Cta.Limite de Cambios'
-12 'Tipo de Operación inválida'
-13 'Recuperar Cargo Inicial a Cobrar'
-14 'Recuperar Impuesto Inicial a Cobrar'
-15 'Recuperar Cargo Posterior a Cobrar'
-16 'Recuperar Impuesto Posterior a Cobrar'
-17 'Asignar Nro de Operación'
-18 'Insertar Movimiento 1'
-19 'Insertar Movimiento 2'
-20 'Actualiza Limite de Cambios'
-21 'Insertar Movimiento 3'
-22 'Insertar Movimiento 4'
-23 'Insertar Movimiento 5'
-24 'Insertar Movimiento 6'
-25 'Insertar Movimiento 7'
-26 'Insertar Movimiento 8'
-27 'Insertar Movimiento 9'
-28 'Insertar Movimiento 10'
-29 'Act.Estado Prepactada'
-30 'Mas de una fila recuperada'
-31 'Plazo de Pre-Pactada no coincide con el Plazo de la Transferencia'
-32 'Tipo de Operación Prepactada no es de TTE'
-33 'No coincide Cargo de Prepactada con HB'
*/
/**** Recupera Cta de Cambios del Cliente */
FUNCTION lf_obt_cta_cliente RETURN varchar2 IS
v_nro_cuenta lc_cta_cambios.nro_cuenta%type;
BEGIN
  SELECT B.NRO_CUENTA
    INTO v_nro_cuenta
    FROM LC_CTA_CAMBIOS B, GE_CTA_CLIENTES  A
   WHERE ESTADO in('N','A')
     AND A.NRO_CUENTA = B.NRO_CUENTA
     AND RELACION = 'P'
     AND A.COD_MODULO = 7
     AND A.COD_MODALIDAD = 70
     AND A.COD_PERSONA = v_cod_persona
     AND ROWNUM = 1;--en teoria debe haber un solo límite x cliente,siempre en USD
   return v_nro_cuenta;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
       --recuperar par dinamico para cuenta bolsa x la oficina
       v_nro_cuenta:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_ofi_cta);
       return v_nro_cuenta;
  WHEN OTHERS THEN
        v_respuesta:=-11;
        p_msj_error := substr(sqlerrm, 1, 200);
  END;
--Funcion que Obtiene la Cotización para el HB
FUNCTION LF_OBT_COT_HB(p_cod_moneda IN VARCHAR2,p_tipo in varchar) RETURN number IS
v_cotizacion ge_cotizaciones.val_ven_electronica%type;
BEGIN
         SELECT decode(p_tipo,'VEN',a.val_ven_electronica,a.val_com_electronica )
           into v_cotizacion
           FROM ba_monedas c, ge_cotizaciones a
          WHERE a.cod_moneda = p_cod_moneda
            AND a.cod_moneda = c.cod_moneda
            AND fecha = (SELECT MAX(fecha)
                           FROM ge_cotizaciones b
                          WHERE b.cod_moneda = a.cod_moneda);
     return v_cotizacion;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
      null;
  WHEN OTHERS THEN
       null;
END;

begin
      ---**************INICIO DE PROCESO PRINCIPAL ****************************************
       -- NLS B.D.
       PRE_CAM_FOR_NUMERICO('.,');
       --Solo se trabajará con Usd y Euros
      if p_cod_mon_tra not in ('USD','EUR') then
        v_respuesta:=-1;
      end if;
      if nvl(p_monto,0)<=0  then
        v_respuesta:=-2;
      end if;
      if p_tip_cargo not in ('OUR','BEN') then
         v_respuesta:=-3 ;
      end if;

      if p_es_noc='S' then
         v_es_noc:='S';
         pag_cta.g_horario := 'N';
      else
         v_es_noc:='N';
         pag_cta.g_horario := 'D';
      end if;
        --Verificamos si el módulo esta cerrado
      if nvl(v_es_noc,'N')='S' then
          pag_cal.pr_obt_dat_calendar(9);
          v_fec_actual :=  pag_cal.g_fec_proxima;
       end if;

       --Validamos Plazo
       if p_plazo not in (0,1,2) then
         v_respuesta:=-4 ;
       end if;
IF v_respuesta=0 THEN
      begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
      v_nro_secuencia:=0;
      v_hora:= null;
      v_can_ope:=1;
      -- *********Obtenemos los datos de la Cuenta *******
      if p_nro_cuenta is not null then
          v_lugar:='Obt.Datos Cta.Cli.';
          pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
              if pag_cta.fu_obt_cod_error() <> 0 then
                  v_lugar:='Obt.Datos Cta.Cli.'||p_nro_cuenta||'-'||pag_cta.fu_obt_msj_error();
                  v_respuesta:=-5;
              end if;
                  --Datos Cta
                  v_cod_mod_cta  := pag_cta.g_ctas.cod_modulo;
                  v_cod_moda_cta  := pag_cta.g_ctas.cod_modalidad;
                  v_cod_ofi_cta  := pag_cta.g_ctas.cod_oficina;
                  v_cod_mon_cta := pag_cta.FU_OBT_MON_CUENTA;
              v_lugar:='Obt. Datos de Persona x Cta';
              IF v_respuesta=0 THEN
                  begin
                    select a.cod_persona,b.nom_completo,b.nro_documento
                     into  v_cod_persona, v_nom_cliente,v_nro_doc_cliente
                      from ge_cta_clientes a, ba_personas b
                       where a.cod_persona=b.cod_persona
                        and a.nro_cuenta= p_nro_cuenta
                        and a.relacion='P';
                  exception
                    when no_data_found then
                        v_cod_persona:= null;
                        v_nom_cliente:= null;
                        v_nro_doc_cliente:=null;
                    when others then
                        v_cod_persona:= null;
                        v_nom_cliente:= null;
                        v_nro_doc_cliente:=null;
                  end;
              END IF;
      end if;
      v_tipo:=null;
      --Si la Moneda de la Cta es Distinto de la de la Transferencia 2 Operaciones
      --Y no es moneda Local
      if v_respuesta = 0 then
        lp_obt_ope_cambio(v_cod_mon_cta, p_cod_mon_tra, p_plazo,
                          -- variables salida
                          v_can_ope, v_cod_tip_ope_vta, v_cod_tip_ope_cpra, v_tipo);
      end if;

       --****** Si viene como prepactada *********************
      if v_respuesta=0 then
          if p_nro_prepactada is not null  then
              --Tiene prepactada- Retomamos la operación Prepactada de Venta Transferencia
              v_lugar:='Obt.Ope.Prep.Venta';
              Begin
                 if v_can_ope <> 2 then
                    select nro_operacion,
                           a.cod_moneda, a.cod_persona, cod_oficina, monto, cotizacion,mto_equ_local,
                           cta_referencia, cod_tra_cargo1, mto_cargo1, cod_tra_cargo2,
                           mto_cargo2, cta_ref_contra4, mto_contra4, nro_cuenta,a.cod_tip_operacion,
                           cta_ref_contra3
                      into v_nro_operacion,
                           v_cod_moneda, v_cod_persona,v_cod_oficina, v_monto,v_cotizacion,v_tot_mon_local_vta,
                           v_cta_referencia, v_cod_tra_cargo1,v_mto_cargo1 ,v_cod_tra_cargo2,
                           v_mto_cargo2,v_cta_ref_contra4,v_mto_contra4,v_cta_cambios,v_cod_tip_ope_pre,
                           v_cta_ref_contra3
                      from ba_monedas c, ba_personas b, lc_ope_pendientes a
                     where nro_diario=p_nro_prepactada
                       and b.cod_persona(+) = a.cod_persona
                       and c.cod_moneda = a.cod_moneda
                       and a.liquidado = 'N'
                       and a.ope_homebanking='S'
                       and trunc(a.fec_operacion)= trunc(v_fec_actual)
                       and rownum=1;
                  else
                    select nro_operacion,
                           a.cod_moneda, a.cod_persona, cod_oficina, monto, cotizacion,mto_equ_local,
                           cta_referencia, cod_tra_cargo1, mto_cargo1, cod_tra_cargo2,
                           mto_cargo2, cta_ref_contra4, mto_contra4, nro_cuenta,a.cod_tip_operacion,
                           cta_ref_contra3
                      into v_nro_operacion,
                           v_cod_moneda, v_cod_persona,v_cod_oficina, v_monto,v_cotizacion,v_tot_mon_local_vta,
                           v_cta_referencia, v_cod_tra_cargo1,v_mto_cargo1 ,v_cod_tra_cargo2,
                           v_mto_cargo2,v_cta_ref_contra4,v_mto_contra4,v_cta_cambios,v_cod_tip_ope_pre,
                           v_cta_ref_contra3
                      from ba_monedas c, ba_personas b, lc_ope_pen_cambios a
                     where nro_diario = p_nro_prepactada
                       and b.cod_persona(+) = a.cod_persona
                       and c.cod_moneda = a.cod_moneda
                       and a.liquidado = 'N'
                       and a.ope_homebanking='S'
                       and a.cod_tip_operacion <> 61
                       and trunc(a.fec_operacion)= trunc(v_fec_actual)
                       and rownum=1;
                  end if;
               exception
                    when no_data_found then
                       v_respuesta:=-6 ;

               end;

                --Si el Monto del Cargo 2 se cobró es OUR , sino BEN
                if nvl(v_mto_cargo2,0)> 0  and p_tip_cargo='BEN' then
                   v_respuesta:=-33;
                elsif nvl(v_mto_cargo2,0)= 0  and p_tip_cargo='OUR' and nvl(p_exonerado,'N') = 'N' then
                    v_respuesta:=-33;
                end if;

                  --Verificamos los Datos Recibidos con lo cargado en la pre-pactada
                if v_cod_moneda <> p_cod_mon_tra then
                 v_respuesta:=-7 ;

                elsif v_monto <> p_monto then
                 v_respuesta:=-8 ;

                elsif v_cod_tip_ope_pre <> v_cod_tip_ope_vta then
                 v_respuesta:=-31 ;
                elsif v_cod_tip_ope_pre not in ('29','292','293', '44','442','443') then
                    --Solo puede ser Vta Transferencia si es prepactada
                    --Canje no realiza mesa de dinero
                     v_respuesta:=-32 ;
                end if;

                --03/02/2015 Si es contra Cta.Cble
                if v_cta_ref_contra4 is not null then
                    v_cod_tip_ope_cpra:= 61; --16;
                    v_tipo:='TTE-MONEXT';
                    v_can_ope:=2;
                end if;

                     --Buscamos si tiene Prepactada 2 (Siempre Compra Debito Cta de Cliente)
                     if v_can_ope = 2 and v_respuesta = 0 then
                         v_lugar:='Obt.Ope.Prep.Compra';
                          Begin
                             select a.monto,a.cotizacion,a.nro_operacion,a.mto_equ_local,a.cta_referencia
                               into v_tot_mon_compra,v_cot_compra,v_nro_ope_compra,v_tot_mon_local,v_cta_referencia_cre
                               from ba_monedas c, ba_personas b, lc_ope_pen_cambios a
                              where a.nro_documento = v_nro_doc_cliente
                                and a.nro_diario = p_nro_prepactada
                                and b.cod_persona(+) = a.cod_persona
                                and c.cod_moneda = a.cod_moneda
                                and a.cta_referencia = p_nro_cuenta
                                and a.cod_tip_operacion = 61 --Siempre debe ser débito en Cta de Cliente
                                and trunc(a.fec_operacion)= trunc(v_fec_actual)
                                and a.liquidado = 'N'
                                and rownum=1;
                          exception
                             when no_data_found then
                                v_respuesta:=-9 ;
                           end;
                     End if;
                      if v_can_ope =1 and v_respuesta=0 then
                         if v_cta_ref_contra3 IS NOT NULL AND v_cta_ref_contra3 <> p_nro_cuenta then
                            v_respuesta:=-10;
                         end If;
                      elsif v_can_ope=2 and v_respuesta=0 then
                       --wa:02/02, se ajusta para que valide si tiene 2 cuentas
                       if v_cta_referencia_cre IS NOT NULL AND v_cta_referencia_cre <> p_nro_cuenta then
                          v_respuesta:=-10;
                       end If;
                      end if;
           else
                   --****** Si no viene como prepactada *********************
                   --obtiene cta de cambios del cliente
                   v_lugar:='Obt.Cta.Cliente';
                   v_cta_cambios := lf_obt_cta_cliente;
           end if;

           if v_tipo='TTE-MONEXT' and v_respuesta=0 then
                      --Es Vta Tra/Compra Deb Contable
                       v_cod_rub_ope:='240402600204999';
           elsif v_tipo='TTE-MONLOC' then
                      --Es Vta Tra/Compra Deb Cta Cliente
                       IF p_cod_mon_tra='USD' then
                          v_cod_rub_ope:='240402600301005';
                       else
                          v_cod_rub_ope:='240402600301017';
                       end if;
           else

                       IF p_cod_mon_tra='USD' then
                       --Es un Canje
                          v_cod_rub_ope:='240402600301005';
                       else
                          v_cod_rub_ope:='240402600301017';
                       end if;
           end if;
        end if;
        v_cod_tip_ope_bcp:='B27';
        v_cod_moneda:=p_cod_mon_tra;
        v_monto:= p_monto;
        v_cod_oficina:= v_cod_ofi_cta ;--se toma de la cuenta
       --*******Obtenemos los cargos y tasas acorde al tipo de Operación
        if v_respuesta=0 then
             begin
                   v_lugar:='Obt.Ope1. Por Tipo';
                  --Buscamos la Operación 1 (De Venta o Canje)
                  select afe_posicion, afe_limite, caja, tip_valor, cod_mod_origen,
                         cod_transaccion, cod_mad_hijo, cod_tra_cargo1, cod_tra_cargo2, cod_tra_cargo3,
                         tip_aplicacion, cod_rubro, descripcion, a.cod_tip_ope_bcp,'001',b.cod_tip_referencia
                    into v_afe_pos_vta, v_afe_lim_vta, v_caj_vta, v_tip_val_vta, v_mod_ori_vta,
                         v_cod_tra_ope_vta, v_mad_hij_vta, v_cod_tra_cargo1, v_cod_tra_cargo2, v_cod_tra_cargo3,
                         v_tip_apl_vta, v_cod_rub_vta, v_des_ope_vta, v_ope_bcp_vta, v_cod_tip_ref_vta,v_cod_ref_cam_vta
                    from lc_tip_ope_oficinas b, lc_tip_operaciones a
                   where b.cod_tip_operacion = a.cod_tip_operacion
                     and b.cod_moneda = v_cod_moneda --moneda de la transf
                     and b.cod_oficina = v_cod_ofi_cta --oficina de la Cta
                     and a.cod_tip_operacion = v_cod_tip_ope_vta --operación Venta/Canje
                     and nivel = 1;

                   --Si son de monedas distintas, debe haber una compra prepactada tambien
                   --16 Compra Déb Cta de Cliente /91 Canje Compra Débito en Cta de Cliente
                   if v_can_ope = 2 then
                        v_lugar:='Obt.Ope2. Por Tipo';
                        select afe_posicion, afe_limite, caja, tip_valor, cod_mod_origen,
                                cod_transaccion, cod_mad_hijo, --sin cargos
                                tip_aplicacion, cod_rubro, descripcion, a.cod_tip_ope_bcp,'001',b.cod_tip_referencia
                           into v_afe_pos_cpra, v_afe_lim_cpra,v_caj_cpra, v_tip_val_cpra, v_mod_ori_cpra,
                                v_cod_tra_ope_cpra, v_mad_hij_cpra,
                                v_tip_apl_cpra, v_cod_rub_cpra,v_des_ope_cpra, v_ope_bcp_cpra, v_cod_tip_ref_cpra,v_cod_ref_cam_cpr
                           from lc_tip_ope_oficinas b, lc_tip_operaciones a
                          where b.cod_tip_operacion = a.cod_tip_operacion
                            and b.cod_moneda = v_cod_moneda --moneda de la transf
                            and b.cod_oficina = v_cod_ofi_cta --oficina de la Cta
                            and a.cod_tip_operacion =v_cod_tip_ope_cpra --operación Compra (Siempre es Débito en Cuenta)
                            and nivel = 1;
                   end if;
               exception
                   when no_data_found then
                        v_respuesta:=-12 ;
               end;
       end if;
     --*************************************************
     if v_respuesta=0 then
         v_cot_venta := p_cotizacion;
         if p_nro_prepactada is null then
            --No es prepactada
            v_lugar:='Obt.Cot.Vta';
            --v_cot_venta := LF_OBT_COT_HB(p_cod_mon_tra,'VEN');
            v_equ_venta := round(v_monto * v_cot_venta,v_redondeo_ml);

            if v_tipo in ('TTE-MONEXT','TTE-MONLOC') then
               v_mad_operacion := 72;
            else
              --Canje
               v_mad_operacion := 74;
            end if;

         else
            --Prepactada
            --v_cot_venta := v_cotizacion;
            v_mad_operacion := 72;
            v_equ_venta := round(v_monto * v_cot_venta,v_redondeo_ml);
            v_tot_mon_local:=v_tot_mon_local_vta;

         end if;
      end if;
  --*************** RECUPERAMOS DATOS DEL CARGO 1****************************************
  if v_respuesta=0 then
    if v_cod_tra_cargo1 is not null then
        v_mto_cargo1:=null;
        v_des_cargo:=null;
        begin
           --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
           /*if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_ofi_cta)  then
               v_lugar:='Obt.Cargos 1.1';
               pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_equ_venta,
                                    v_cod_ofi_cta, v_cta_cambios, null, v_des_cargo,
                                    v_mto_cargo1, v_cod_tasa, v_val_tasa);
           els*/
           if v_cod_persona is not null then
              if p_cod_mon_tra <> v_cod_mon_cta then
                 v_lugar:='Obt.Cargos 1.2';
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_equ_venta,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo1, v_cod_tasa, v_val_tasa);
              else
                 --Misma moneda que la cuenta
                 v_lugar:='Obt.Cargos 1.3';
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, null,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo1, v_cod_tasa, v_val_tasa);

                 v_mto_cargo1:=v_val_tasa;

             end if;

           end if;
        exception
           when others then
                v_respuesta:=-13;
                p_msj_error := substr(sqlerrm, 1, 200);
        end;
     end if;
       if v_cod_moneda= v_mon_local then
         v_mto_cargo1 := round(nvl(v_mto_cargo1,0), v_redondeo_ml);
       else
         v_mto_cargo1 := round(nvl(v_mto_cargo1,0), v_redondeo_me);
       end if;  
       --Se almacena valor original del cargo y la tasa
       v_cod_tasa_ini  := v_cod_tasa;
       --
       v_cod_tasa      :=NULL;
       v_val_tasa      :=NULL;
     if nvl(v_mto_cargo1,0) > 0 and v_respuesta=0 then
        --Verificar si tienen impuestos asociados
         v_lugar:='Obt.Imp 1 ';
         begin
              -- DYDMR-4666 Ago/2016 utiliza codigo de moneda para redondeo si la operacion es TTE-CANJE
              v_cod_mon_imp := null;
 		          if v_tipo='TTE-CANJE'then
                 v_cod_mon_imp := v_cod_moneda;
              end if;
              -- Tasa Generica
              pal_cam.pr_obt_impuestos(v_cod_tra_cargo1, v_mad_operacion, v_mto_cargo1,
                                   v_cod_ofi_cta, v_tra_impuesto, v_impuesto,
                                   v_cod_tasa, v_val_tasa, v_cod_mon_imp); -- DYDMR-4666 Ago/2016
              -- DYDMR-5780 05/2018 recupera tasa personalizada para el cliente                     
              pal_cam.pr_obt_impuestos(v_cod_tra_cargo1, v_mad_operacion, v_mto_cargo1,
                                   v_cod_ofi_cta, v_tra_impuesto, v_imp_personalizado,
                                   v_cod_tasa, v_val_tasa, v_cod_mon_imp, v_cod_persona);
         exception
           when others then
              v_respuesta:=-14;
              p_msj_error := substr(sqlerrm, 1, 200);
         end;
        --Se guarda el impuesto del movimiento para luego utilizarlo en el desglose del IVA si aplica.
        v_mov_impuesto := nvl(v_imp_personalizado,0);
        -- Si tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
        -- DYDMR-5780 05/2018 comentado por que el monto ya se resta al generar registro del movimiento
        /*if v_impuesto is not null and nvl(v_val_tasa,0) = 0 and v_respuesta=0 then
           v_mto_cargo1 :=  v_mto_cargo1 - v_impuesto;
        end if;*/ 
     end if;
 end if;
  --*************** RECUPERAMOS DATOS DEL CARGO 2****************************************
  --Si tipo es BEN no se cobra cargo II (OUR) Se cobra cargo 2
 if p_tip_cargo= 'OUR' and v_respuesta=0 THEN

     if v_cod_tra_cargo2 is not null then
        v_mto_cargo2:=null;
        v_des_cargo:=null;
        begin
           --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
           /*if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_ofi_cta) then
              v_lugar:='Obt.Cargos 2.1';
              pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_mad_operacion, v_cod_moneda, v_monto, v_equ_venta,
                                    v_cod_ofi_cta, v_cta_cambios, null, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa1, v_val_tasa1);
           els*/
           if v_cod_persona is not null then
             if p_cod_mon_tra <> v_cod_mon_cta then
                v_lugar:='Obt.Cargos 2.2';
                pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_mad_operacion, v_cod_moneda,v_monto, v_equ_venta,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa1, v_val_tasa1);
              else
                 v_lugar:='Obt.Cargos 2.3';
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_mad_operacion, v_cod_moneda,v_monto, null,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa1, v_val_tasa1);

                 v_mto_cargo2:=v_val_tasa1;
              end if;
           end if;
        exception
           when others then
                v_respuesta:=-15;
                p_msj_error := substr(sqlerrm, 1, 200);
        end;
     end if;
 
       if v_cod_moneda= v_mon_local then
         v_mto_cargo2 := round(nvl(v_mto_cargo2,0), v_redondeo_ml);
       else
         v_mto_cargo2 := round(nvl(v_mto_cargo2,0), v_redondeo_me);
       end if; 

     --Se almacena valor original del cargo y la tasa
     v_cod_tasa_ini1  := v_cod_tasa1;
     v_cod_tasa1      :=NULL;
     v_val_tasa1      :=NULL;
     --
     if nvl(v_mto_cargo2,0) > 0 and v_respuesta=0  then
        --Verificar si tienen impuestos asociados
        v_lugar:='Obt.Impuesto1';
        begin
         -- Tasa Generica
         pal_cam.pr_obt_impuestos(v_cod_tra_cargo2, v_mad_operacion, v_mto_cargo2,
                                 v_cod_ofi_cta, v_tra_impuesto1, v_impuesto1,
                                 v_cod_tasa1, v_val_tasa1);
         -- DYDMR-5780 05/2018 recupera tasa personalizada para el cliente
         pal_cam.pr_obt_impuestos(v_cod_tra_cargo2, v_mad_operacion, v_mto_cargo2,
                                 v_cod_ofi_cta, v_tra_impuesto1, v_imp_personalizado1,
                                 v_cod_tasa1, v_val_tasa1, null, v_cod_persona); -- DYDMR-8895 NAF 05/2018
        exception
          when others then
             v_respuesta:=-16;
             p_msj_error := substr(sqlerrm, 1, 200);
        end;
        --Se guarda el impuesto del movimiento para luego utilizarlo en el desgloze del IVA si aplica.
        v_mov_impuesto1 := nvl(v_imp_personalizado1,0);
        -- Si tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
        -- DYDMR-5780 05/2018 comentado por que el monto ya se resta al generar registro del movimiento
        /*if v_impuesto1 is not null and nvl(v_val_tasa1,0) = 0 and v_respuesta=0 then
           v_mto_cargo2 :=  v_mto_cargo1 - v_impuesto1;
        end if;*/
     end if;
  end if;
If v_tipo ='TTE-MONEXT' and v_respuesta=0 then
   --***************MOVIMIENTO DE VENTA TRANSFERENCIA***************************
      IF p_nro_prepactada is  null then
            --asignar nro de recibo a la operación
               begin
                 v_lugar:='Obt.Nro.Ope.1';
                 v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
                 v_lugar:='Act.Par.Din.';
                 prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
                 v_lugar:='Obt.Redondeo';
                 v_tot_mon_local := ROUND(NVL(v_cot_venta,0) * v_monto,v_redondeo_ml);
               exception
                  when others then
                     p_msj_error := substr(sqlerrm, 1, 200);
                     if sqlcode <= -20000 then
                        v_respuesta:= -17;
                     end if;
               end;

          end if;
          v_lugar:='Obt.Cotizacion';
          v_cotizacion :=LF_OBT_COT_HB(v_mon_fuerte,'VEN'); --pag_gen.FU_OBT_COTIZACION(v_mon_fuerte,v_fec_actual);
          --******* Generamos Movimiento 1 *******************
          --asigno nro_referencia, se utiliza secuencia para evitar bloqueos
          v_nro_secuencia:=1;
          if v_cod_tip_ope_vta is not null and v_respuesta=0 then
            v_lugar:='Obt.S_NRO_REF_';
             v_nro_ref_vta := fue_obt_sig_secuencia('S_NRO_REF_'||lpad(v_cod_tip_ref_vta,3,0)||'');
          end if;
          v_hora := to_char(sysdate,'HH24:MI:SS');
          v_lugar:='Obt.Hor.Disponible 1';
          v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_noc);
          r_gmovi.fecha         := v_fec_actual;
          r_gmovi.hora          := v_hora;
          r_gmovi.cod_usuario   := v_cod_usuario;
          r_gmovi.nro_secuencia := v_nro_secuencia;
          r_gmovi.fec_valor     := v_fec_actual;
          r_gmovi.monto         := abs(v_monto);
          r_gmovi.nro_cuenta    := null;
          r_gmovi.cod_moneda    := v_cod_moneda;
          r_gmovi.cod_oficina   := v_cod_oficina;
          r_gmovi.estado        := v_est_mvto;
          r_gmovi.cod_ofi_origen:= v_cod_oficina;
          r_gmovi.concepto      := v_nom_cliente;
          r_gmovi.cod_tasa      := null;
          r_gmovi.val_tasa      := null;
          r_gmovi.Cod_rubro     := v_cod_rub_vta;
          r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
          r_gmovi.reversado     := 'N';
          r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
          r_gmovi.cod_mod_padre := v_mod_ori_vta;
          r_gmovi.cod_mad_padre := v_mad_hij_vta;
          r_gmovi.cod_transaccion:=v_cod_tra_ope_vta;
          r_gmovi.cod_modulo    := v_mod_ori_vta;
          r_gmovi.cod_modalidad := v_mad_hij_vta;
          r_gmovi.mto_equ_local := abs(v_tot_mon_local);
          r_gmovi.cotizacion    := v_cot_venta;
          r_gmovi.cod_bco_central:= v_cod_tip_ope_bcp;
          r_gmovi.nro_documento := v_nro_operacion;
          r_gmovi.nro_documento2 := v_nro_ref_vta;
          r_gmovi.tip_mov_rubro  := 'C';
          r_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_vta;
          r_gmovi.cod_persona    := v_cod_persona;
          r_gmovi.emi_aviso     := 'N';
          v_lugar:='Ins.Movimiento 1';
          begin
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
          exception
            when others then
              v_respuesta:=-18;
              p_msj_error := substr(sqlerrm, 1, 200);
          end;
          --***********************************************************************
          --********* Generamos Movimiento 2---De la Cuenta de Cambios ************
          v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
          --- genera movimiento ---
          --recuperar datos de la cta de cambios
               pag_cta.pr_obt_cuenta(v_cta_cambios);
               v_est_cta_cam := pag_cta.g_ctas.estado;
               v_cod_ofi_cta_cam := pag_cta.g_ctas.cod_oficina;
               if pag_cta.fu_obt_cod_error() <> 0 then
                  v_lugar:='Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error();
                  v_respuesta:=-11;
               end if;
               --solo si afecta límite
               if v_afe_lim_vta <> 'S' and v_respuesta=0 THEN
                  v_lim_utilizado := 0;
               else
                  --si moneda de la operación diferente al límite convertir
                  if v_cod_moneda <> v_mon_fuerte and v_respuesta=0 then
                     v_lim_utilizado:= pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_monto);--para q busque la correspondiente
                  else
                     v_lim_utilizado:= v_monto;
                  end if;
               end if;
               --actualización de límite, sólo si afecta recupera retención
               begin
               if nvl(v_afe_lim_vta,'N')='S' then
                 select estado, cod_oficina
                   into v_est_cta_cam, v_cod_ofi_cta_cam
                   from lc_cta_cambios
                  where nro_cuenta = v_cta_cambios
                    for update of estado;
                 update lc_cta_cambios
                    set mto_utilizado = nvl(mto_utilizado,0) + nvl(v_lim_utilizado,0),
                        fec_ult_movimiento = v_fec_actual,
                        estado = decode(estado,'A','N',estado),
                        fec_cam_estado =decode(estado,'A',v_fec_actual,fec_cam_estado)
                  where lc_cta_cambios.nro_cuenta = v_cta_cambios;
                 IF v_afe_lim_vta = 'S' THEN --solo si afecta límite
                    --obtiene retención
                    pal_cam.pr_obt_retencion(v_cod_tip_ope_vta, null, null,
                           v_mon_fuerte, v_cod_oficina,v_cod_retencion, v_fec_fin_retencion);
                 end if;
               END IF;
                 r_gmovi.hora          := v_hora;
                 r_gmovi.cod_usuario   := v_cod_usuario;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 r_gmovi.cod_modulo      := 7;
                 r_gmovi.cod_modalidad   := 70;
                 r_gmovi.cod_oficina     := v_cod_ofi_cta_cam;
                 r_gmovi.cod_moneda      := v_mon_fuerte;
                 r_gmovi.cod_tra_padre   := v_cod_tra_ope_vta; --
                 r_gmovi.cod_transaccion := 760;
                 r_gmovi.monto           := v_lim_utilizado;
                 r_gmovi.nro_documento   := v_nro_operacion;
                 r_gmovi.COD_REF_CAMBIO := v_cod_tip_ref_vta;
                 r_gmovi.NRO_DOCUMENTO2  := v_cod_persona;
                 r_gmovi.REFERENCIA      := null;
                 r_gmovi.concepto        := 'Operación Cambios Límite';
                 r_gmovi.cod_rubro       := NULL;
                 r_gmovi.nro_cuenta      := v_cta_cambios;
                 r_gmovi.tip_mov_rubro   := null;
                 r_gmovi.cod_persona     := v_cod_persona;
                 if v_cod_moneda <> v_mon_fuerte then
                    r_gmovi.cotizacion   := pag_gen.fu_obt_cotizacion(v_mon_fuerte);--cotizacion del límite en la moneda fuerte
                 else
                    r_gmovi.cotizacion := v_cot_venta;
                 end if;
                 r_gmovi.mto_equ_local   := ROUND(NVL(v_lim_utilizado,0)*r_gmovi.cotizacion,v_redondeo_ml);
                 r_gmovi.cod_bco_central := v_ope_bcp_cpra;
                 r_gmovi.COD_RETENCION   := v_cod_retencion;
                 r_gmovi.FEC_FIN_RETENCION:= v_fec_fin_retencion;
                 r_gmovi.cod_tip_ope_cambio:= null;
                 begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                 exception
                    when others then
                      v_respuesta:=-19;
                      p_msj_error := substr(sqlerrm, 1, 200);
                 end;
                 r_gmovi.REFERENCIA      := null;
                 --movimiento x el cambio de estado de la cuenta si corresponde
                 if v_est_cta_cam = 'A' then
                    v_nro_secuencia := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia  := v_nro_secuencia;
                    r_gmovi.cod_modulo      := 7;
                    r_gmovi.cod_modalidad   := 70;
                    r_gmovi.cod_oficina     := v_cod_ofi_cta;
                    r_gmovi.cod_moneda      := v_mon_fuerte;
                    r_gmovi.fec_valor       := v_fec_actual;
                    r_gmovi.cod_tra_padre   := 401;
                    r_gmovi.cod_mod_padre   := 7;
                    r_gmovi.cod_mad_padre   := 70;
                    r_gmovi.cod_transaccion := 401;
                    r_gmovi.monto           := null;
                    r_gmovi.nro_documento   := null;
                    r_gmovi.NRO_DOCUMENTO2  := null;
                    r_gmovi.concepto        := 'Cambio de Estado ';
                    r_gmovi.est_cuenta      := 'N';
                    r_gmovi.cod_rubro       := NULL;
                    r_gmovi.nro_cuenta      := v_cta_cambios;
                    r_gmovi.tip_mov_rubro   := null;
                    r_gmovi.cotizacion      := null;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_bco_central := null;
                    r_gmovi.COD_RETENCION   := null;
                    r_gmovi.FEC_FIN_RETENCION :=null;
                    r_gmovi.COD_REF_CAMBIO   := null;
                    r_gmovi.cod_tip_ope_cambio := null;
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-19;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                  end if;
                 v_cod_retencion:=null;
                 v_fec_fin_retencion:=null;
                 r_gmovi.COD_RETENCION   := v_cod_retencion;
                 r_gmovi.FEC_FIN_RETENCION:= v_fec_fin_retencion;
                EXCEPTION
                  WHEN OTHERS THEN
                    v_respuesta:=-20;
                    p_msj_error := substr(sqlerrm, 1, 200);
                    raise_application_error(-20016,'Actualiza límite. '||sqlerrm);

                END;
                 v_cod_retencion         :=null;
                 v_fec_fin_retencion     :=null;
                 r_gmovi.COD_RETENCION   := v_cod_retencion;
                 r_gmovi.FEC_FIN_RETENCION:= v_fec_fin_retencion;
        --********* Generamos Movimiento 3---Cargo de Cambios 1 ************
         if nvl(v_mto_cargo1,0)>0 and v_respuesta=0 then
            v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
            v_mto_car_1:= nvl(v_mto_cargo1,0)-nvl(v_impuesto,0);
            --- genera movimiento ---
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.hora          := v_hora;
            r_gmovi.cod_usuario   := v_cod_usuario;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.fec_valor     := v_fec_actual;
            r_gmovi.monto         := v_mto_car_1;
            r_gmovi.nro_cuenta    := null;
            r_gmovi.cod_moneda    := v_mon_local;
            r_gmovi.cod_oficina   := v_cod_oficina;
            r_gmovi.estado        := v_est_mvto;
            r_gmovi.cod_ofi_origen:= v_cod_oficina;
            r_gmovi.concepto      := 'Cargos de Cambios';
            r_gmovi.cod_tasa      := v_cod_tasa_ini;
            r_gmovi.val_tasa      := v_mto_cargo1;
            r_gmovi.Cod_rubro     := NULL;
            r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
            r_gmovi.reversado     := 'N';
            r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
            r_gmovi.cod_mod_padre := v_mod_ori_vta;
            r_gmovi.cod_mad_padre := v_mad_hij_vta;
            r_gmovi.cod_transaccion:=v_cod_tra_cargo1;
            r_gmovi.cod_modulo    := v_mod_ori_vta;
            r_gmovi.cod_modalidad := v_mad_hij_vta;
            r_gmovi.mto_equ_local := NULL;
            r_gmovi.cotizacion    := NULL;
            r_gmovi.cod_bco_central:= NULL;
            r_gmovi.nro_documento := v_nro_operacion;
            r_gmovi.nro_documento2 := v_nro_ref_vta;
            r_gmovi.nro_documento3 := null;
            r_gmovi.nro_documento4 := null;
            r_gmovi.tip_mov_rubro  := null;
            r_gmovi.cod_tip_ope_cambio := null;
            r_gmovi.cod_persona    := v_cod_persona;
            r_gmovi.emi_aviso     := 'N';
            v_lugar:='Ins. Movimiento 3';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-21;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
            --********* Generamos Movimiento 4---Impuesto de Cambios 1 ************
            -- genero movimiento x el impuesto si no tiene exonerado
            if v_mov_impuesto is not null and nvl(v_val_tasa,0) <> 0 and v_respuesta=0 and nvl(v_mov_impuesto,0) > 0 then
                  v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                  v_nro_secuencia         := v_nro_secuencia;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_transaccion := v_tra_impuesto;
                  r_gmovi.monto           := v_mov_impuesto; -- DYDMR-5780 05/2018
                  r_gmovi.COD_TASA        := v_cod_tasa;
                  r_gmovi.VAL_TASA        := v_val_tasa;
                  r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                  v_lugar:='Ins. Movimiento 4';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-22;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
            end if;
           end if;
            if p_tip_cargo= 'OUR' and v_respuesta=0 AND NVL(v_mto_cargo2,0) >0 then
              --********* Generamos Movimiento 5---Cargo de Cambios 2 ************
              v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
              v_mto_car_2:= nvl(v_mto_cargo2,0)-nvl(v_impuesto1,0);
              --- genera movimiento ---
              r_gmovi.fecha         := v_fec_actual;
              r_gmovi.hora          := v_hora;
              r_gmovi.cod_usuario   := v_cod_usuario;
              r_gmovi.nro_secuencia := v_nro_secuencia;
              r_gmovi.fec_valor     := v_fec_actual;
              r_gmovi.monto         := v_mto_car_2;
              r_gmovi.nro_cuenta    := null;
              r_gmovi.cod_moneda    := v_mon_local;
              r_gmovi.cod_oficina   := v_cod_oficina;
              r_gmovi.estado        := v_est_mvto;
              r_gmovi.cod_ofi_origen:= v_cod_oficina;
              r_gmovi.concepto      := 'Cargo de Cambios';
              r_gmovi.cod_tasa      := v_cod_tasa_ini1;
              r_gmovi.val_tasa      := v_mto_cargo2;
              r_gmovi.Cod_rubro     := NULL;
              r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
              r_gmovi.reversado     := 'N';
              r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
              r_gmovi.cod_mod_padre := v_mod_ori_vta;
              r_gmovi.cod_mad_padre := v_mad_hij_vta;
              r_gmovi.cod_transaccion:=v_cod_tra_cargo2;
              r_gmovi.cod_modulo    := v_mod_ori_vta;
              r_gmovi.cod_modalidad := v_mad_hij_vta;
              r_gmovi.mto_equ_local := NULL;
              r_gmovi.cotizacion    := NULL;
              r_gmovi.cod_bco_central:= NULL;
              r_gmovi.nro_documento := v_nro_operacion;
              r_gmovi.nro_documento2 := v_nro_ref_vta;
              r_gmovi.nro_documento3 := null;
              r_gmovi.nro_documento4 := null;
              r_gmovi.tip_mov_rubro  := null;
              r_gmovi.cod_tip_ope_cambio := null;
              r_gmovi.cod_persona    := v_cod_persona;
              r_gmovi.emi_aviso     := 'N';
              v_lugar:='Ins. Movimiento 5';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-23;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
             --********* Generamos Movimiento 6---Impuesto de Cambios 2 ************
              v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;

              --DYDMR-2010: ITGF - Cargos cobrados y no facturados desde la WEB - SC 17247
              if v_mov_impuesto1 is not null and nvl(v_val_tasa1,0) <> 0 and v_respuesta=0 and nvl(v_mov_impuesto1,0)>0 then
                    v_nro_secuencia         := v_nro_secuencia;
                    r_gmovi.nro_secuencia   := v_nro_secuencia;
                    r_gmovi.cod_transaccion := v_tra_impuesto1;
                    r_gmovi.monto           := v_mov_impuesto1;
                    r_gmovi.COD_TASA        := v_cod_tasa1;
                    r_gmovi.VAL_TASA        := v_val_tasa1;
                    r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                    v_lugar:='Ins.Movimiento 6';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-24;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
              end if;
          END IF;

         --********* Generamos Movimiento 7---Débito en Cta************
              --Calculamos el total en Guaranies
         if v_respuesta=0  then
              -- DYDMR-8959 NAF 12/2018
              if v_mov_impuesto != v_impuesto then
                 v_mto_car_1 := v_mto_cargo1 - v_impuesto;
              else
                 v_mto_car_1 := v_mto_cargo1;
              end if;
              if v_mov_impuesto1 != v_impuesto1 then
                 v_mto_car_2 := v_mto_cargo2 - v_impuesto1;
              else
                 v_mto_car_2 := v_mto_cargo2;
              end if;
              v_tot_gral:=nvl(abs(v_tot_mon_local),0)+nvl(v_mto_car_1,0)+nvl(v_mto_car_2,0);
              v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
              --- genera movimiento ---
              r_gmovi.fecha         := v_fec_actual;
              r_gmovi.hora          := v_hora;
              r_gmovi.cod_usuario   := v_cod_usuario;
              r_gmovi.nro_secuencia := v_nro_secuencia;
              r_gmovi.fec_valor     := v_fec_actual;
              r_gmovi.monto         := abs(v_tot_gral);
              r_gmovi.nro_cuenta    := null;
              r_gmovi.cod_moneda    := v_mon_local;--Verificar
              r_gmovi.cod_oficina   := v_cod_oficina;
              r_gmovi.estado        := v_est_mvto;
              r_gmovi.cod_ofi_origen:= v_cod_oficina;
              r_gmovi.Cod_rubro     := v_cod_rub_ope;
              r_gmovi.concepto      := 'Operación de Cambios-Déb. Ctble';
              r_gmovi.cod_tasa      := null;
              r_gmovi.val_tasa      := null;
              r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
              r_gmovi.reversado     := 'N';
              r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
              r_gmovi.cod_mod_padre := v_mod_ori_vta;
              r_gmovi.cod_mad_padre := v_mad_hij_vta;
              r_gmovi.cod_transaccion:=842;
              r_gmovi.cod_modulo    := v_mod_ori_vta;
              r_gmovi.cod_modalidad := v_mad_hij_vta;
              r_gmovi.mto_equ_local := NULL;
              r_gmovi.cotizacion    := NULL;
              r_gmovi.cod_bco_central:= v_cod_tip_ope_bcp;
              r_gmovi.nro_documento := v_nro_operacion;
              r_gmovi.nro_documento2 := v_nro_ref_vta;
              r_gmovi.nro_documento3 := null;
              r_gmovi.nro_documento4 := null;
              r_gmovi.tip_mov_rubro  := 'D';
              r_gmovi.cod_tip_ope_cambio := null;
              r_gmovi.cod_persona    := v_cod_persona;
              r_gmovi.emi_aviso     := 'N';
              r_gmovi.cod_tip_ope_cambio  := 9;
              v_lugar:='Ins. Movimiento 7';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-25;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
          end if;
        --***********************MOVIMIENTO DE COMPRA DEBITO CTA CONTABLE*************************+
        if v_cod_mon_cta <> p_cod_mon_tra and v_respuesta=0 then
              --Tomamos el total en Gs.
              v_tot_mon_compra:= abs(v_tot_gral);
              --Tomamos la Cotización de Compra de la Moneda (De la Cta de Cliente)
              --if p_nro_prepactada is null then
              --   v_lugar:='Obt.Cot.Cpra';
                 v_cot_compra := p_cot_contra;--LF_OBT_COT_HB(v_cod_mon_cta,'COM');--pal_cam.FU_OBT_COT_COMPRA(v_cod_mon_cta);
              --end if;

              if v_cod_tip_ope_cpra is not null then
                    v_lugar:='Obt.S_NRO_REF_';
                    v_nro_ref_cpra := fue_obt_sig_secuencia('S_NRO_REF_'||lpad(v_cod_tip_ref_cpra,3,0)||'');
               end if;
               v_redondeo_me := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,v_cod_mon_cta);
               v_tot_mon_compra:=round(nvl(v_tot_mon_compra,0)/nvl(v_cot_compra,0),v_redondeo_me);
              --Hacemos la Conversión
              v_nro_secuencia:=0;
              v_hora:= null;
              v_lugar:='Obt.Hor Disponible 2';
              v_hora := to_char(sysdate,'HH24:MI:SS');
              v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_noc);
              --******* Generamos Movimiento 1 *******************
              if p_nro_prepactada is null then
                v_lugar:='Obt.Nro.Rec.2';
                 v_nro_operacion2 := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
                 v_lugar:='Act.Nro.Rec.2';
                 prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion2);
              else
                v_nro_operacion2:=v_nro_ope_compra;
              end if;
             ------------------------------------------
               -- Actualiza la Cuenta Débito / Destino
               --v_respuesta:=-26;
               v_lugar:='Act.Saldo.Cta.Cli';
                pag_cta.pr_act_operacion(p_nro_cuenta,
                 v_hora,--HORA
                 'D',
                 v_cod_mon_cta, --Moneda de la Operación
                 v_tot_mon_compra,
                 255,  -- COD_TRA_PADRE (venta divisas en efectivo)
                 503,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                 v_nro_operacion2, --nro_documento
                 v_cot_compra,       --COTIZACION
                 v_cod_oficina,      --cod_ofi_origen
                 7,                --cod_mod_padre
                 71,    --o abmc.modalidad   --cod_mad_padre
                 null,                       --cod_tasa
                 null,                       --val_tasa
                 'Operación de Cambios '||v_nro_operacion2,
                 'N',                        --emi_aviso
                 v_nro_secuencia,
                 v_fec_actual);
                  --Hacemos Update del Movimiento para igualar al CORE
                 IF nvl(v_es_noc,'N')='N' THEN
                    update ge_movimientos a
                    set a.cod_bco_central='A19'
                       ,a.cod_ref_cambio=v_cod_ref_cam_cpr
                       ,a.cod_tip_ope_cambio=61
                       ,a.cod_persona= v_cod_persona
                       ,a.cod_modulo=v_cod_mod_cta
                       ,a.cod_modalidad=v_cod_moda_cta
                       ,a.nro_documento2=v_nro_ref_cpra
                    where a.fecha=trunc(v_fec_actual)
                    and a.cod_usuario=v_cod_usuario
                    and a.hora=v_hora
                    and a.nro_documento=v_nro_operacion2   
                    and a.cod_tra_padre=255
                    and a.cod_transaccion=503;
                 ELSE
                    update ge_movimientos_noc a
                    set a.cod_bco_central='A19'
                       ,a.cod_ref_cambio=v_cod_ref_cam_cpr
                       ,a.cod_tip_ope_cambio=61
                       ,a.cod_persona= v_cod_persona
                       ,a.cod_modulo=v_cod_mod_cta
                       ,a.cod_modalidad=v_cod_moda_cta
                       ,a.nro_documento2=v_nro_ref_cpra
                     where a.fecha=trunc(v_fec_actual)
                     and a.cod_usuario=v_cod_usuario
                     and a.hora=v_hora
                     and a.nro_documento=v_nro_operacion2
                     and a.cod_tra_padre=255
                     and a.cod_transaccion=503;
                END IF;
              v_nro_secuencia       := v_nro_secuencia+1;

              --********* Generamos Movimiento 2---De la Cuenta de Cambios ************
              --- genera movimiento ---
               pag_cta.pr_obt_cuenta(v_cta_cambios);
               v_est_cta_cam := pag_cta.g_ctas.estado;
               v_cod_ofi_cta_cam := pag_cta.g_ctas.cod_oficina;
               if pag_cta.fu_obt_cod_error() <> 0 then
                  v_lugar:='Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error();
                  v_respuesta:=-11;
                  raise_application_error(-20015,'Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error());
               end if;

              r_gmovi.fecha         := v_fec_actual;
              r_gmovi.hora          := v_hora;
              r_gmovi.cod_usuario   := v_cod_usuario;
              r_gmovi.nro_secuencia := v_nro_secuencia;
              r_gmovi.fec_valor     := v_fec_actual;
              r_gmovi.monto         := 0;
              r_gmovi.nro_cuenta    := v_cta_cambios;
              r_gmovi.cod_moneda    := 'USD';
              r_gmovi.cod_oficina   := v_cod_ofi_cta_cam;
              r_gmovi.estado        := 'N';
              r_gmovi.cod_ofi_origen:= v_cod_oficina;
              r_gmovi.concepto      := 'Limite de Cambios';
              r_gmovi.cod_tasa      := null;
              r_gmovi.val_tasa      := null;
              r_gmovi.Cod_rubro     := null;
              r_gmovi.cod_ref_cambio:= v_cod_ref_cam_cpr;
              r_gmovi.reversado     := 'N';
              r_gmovi.cod_tra_padre := 255;
              r_gmovi.cod_mod_padre := 7;
              r_gmovi.cod_mad_padre := 71;
              r_gmovi.cod_transaccion := 760;
              r_gmovi.cod_modulo    := 7;
              r_gmovi.cod_modalidad := 70;
              r_gmovi.mto_equ_local := 0;
              if v_cod_moneda <> v_mon_fuerte then
                    r_gmovi.cotizacion   := pag_gen.fu_obt_cotizacion(v_mon_fuerte);--cotizacion del límite en la moneda fuerte
              else
                    r_gmovi.cotizacion := v_cot_compra;
              end if;
              r_gmovi.cod_bco_central:= 'A19';
              r_gmovi.nro_documento := v_nro_operacion2;
              r_gmovi.nro_documento2 := v_cod_persona;
              r_gmovi.nro_documento3 := null;
              r_gmovi.nro_documento4 := null;
              r_gmovi.tip_mov_rubro  := null;
              r_gmovi.cod_tip_ope_cambio := null;
              r_gmovi.cod_persona    := v_cod_persona;
              r_gmovi.emi_aviso     := 'N';
              v_lugar:='Ins.Mov.2.Cpra.';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-27;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;

              --********* Generamos Movimiento 3---Cargo de Cambios 1 ************
                  v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                  --- genera movimiento ---
                  r_gmovi.fecha         := v_fec_actual;
                  r_gmovi.hora          := v_hora;
                  r_gmovi.cod_usuario   := v_cod_usuario;
                  r_gmovi.nro_secuencia := v_nro_secuencia;
                  r_gmovi.fec_valor     := v_fec_actual;
                  r_gmovi.monto         := abs(v_tot_gral);
                  r_gmovi.nro_cuenta    := null;
                  r_gmovi.cod_moneda    := v_mon_local;
                  r_gmovi.cod_oficina   := v_cod_oficina;
                  r_gmovi.estado        := 'N';
                  r_gmovi.cod_ofi_origen:= v_cod_oficina;
                  r_gmovi.concepto      := 'Operación de Cambios-Créd. Ctble';
                  r_gmovi.Cod_rubro     := v_cod_rub_ope;
                  r_gmovi.cod_tasa      := null;
                  r_gmovi.val_tasa      := null;
                  r_gmovi.cod_ref_cambio:= v_cod_ref_cam_cpr;
                  r_gmovi.reversado     := 'N';
                  r_gmovi.cod_tra_padre := 255;
                  r_gmovi.cod_mod_padre :=7;
                  r_gmovi.cod_mad_padre := 71;
                  r_gmovi.cod_transaccion:= 741;
                  r_gmovi.cod_modulo    := 7;
                  r_gmovi.cod_modalidad := 71;
                  r_gmovi.mto_equ_local := NULL;
                  r_gmovi.cotizacion    := NULL;
                  r_gmovi.cod_bco_central:= 'A19';
                  r_gmovi.nro_documento := v_nro_operacion2;
                  r_gmovi.nro_documento2 := v_nro_ref_cpra;
                  r_gmovi.nro_documento3 := null;
                  r_gmovi.nro_documento4 := null;
                  r_gmovi.tip_mov_rubro  := 'C';
                  r_gmovi.cod_tip_ope_cambio := 4;
                  r_gmovi.cod_persona    := v_cod_persona;
                  r_gmovi.emi_aviso     := 'N';
                  v_lugar:='Ins.Mov.3 Compra';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-28;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
        end if;
elsif v_tipo ='TTE-MONLOC' and v_respuesta=0 then
  --***************OPERACION DE VENTA DE DIVISAS MON LOCAL *******************************
        IF p_nro_prepactada is  null and v_respuesta=0 then
            --asignar nro de recibo a la operación
               begin
                 v_lugar:='Obt.Nro.Ope.1';
                 v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
                 v_lugar:='Act.Par.Din.';
                 prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
                 v_lugar:='Obt.Redondeo';
                 v_tot_mon_local := ROUND(NVL(v_cot_venta,0) * v_monto,v_redondeo_ml);
               exception
                  when others then
                     if sqlcode <= -20000 then
                        v_lugar:='Asigna Nro.Oper. '||sqlerrm;
                        v_respuesta:=-17 ;
                     end if;
                     p_msj_error := substr(sqlerrm, 1, 200);
               end;

          end if;

          if v_respuesta=0 then
              v_lugar:='Obt.Cotizacion';
              --v_cotizacion := v_cot_venta;
              --******* Generamos Movimiento 1 *******************
              --asigno nro_referencia, se utiliza secuencia para evitar bloqueos
              v_nro_secuencia:=1;
              if v_cod_tip_ope_vta is not null then
                v_lugar:='Obt.S_NRO_REF_';
                 v_nro_ref_vta := fue_obt_sig_secuencia('S_NRO_REF_'||lpad(v_cod_tip_ref_vta,3,0)||'');
              end if;
              v_hora := to_char(sysdate,'HH24:MI:SS');
              v_lugar:='Obt.Hor.Disponible 1';
              v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_noc);
              r_gmovi.fecha         := v_fec_actual;
              r_gmovi.hora          := v_hora;
              r_gmovi.cod_usuario   := v_cod_usuario;
              r_gmovi.nro_secuencia := v_nro_secuencia;
              r_gmovi.fec_valor     := v_fec_actual;
              r_gmovi.monto         := abs(v_monto);
              r_gmovi.nro_cuenta    := null;
              r_gmovi.cod_moneda    := v_cod_moneda;
              r_gmovi.cod_oficina   := v_cod_oficina;
              r_gmovi.estado        := v_est_mvto;
              r_gmovi.cod_ofi_origen:= v_cod_oficina;
              r_gmovi.concepto      := v_nom_cliente;
              r_gmovi.cod_tasa      := null;
              r_gmovi.val_tasa      := null;
              r_gmovi.Cod_rubro     := v_cod_rub_vta;
              r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
              r_gmovi.reversado     := 'N';
              r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
              r_gmovi.cod_mod_padre := v_mod_ori_vta;
              r_gmovi.cod_mad_padre := v_mad_hij_vta;
              r_gmovi.cod_transaccion:=v_cod_tra_ope_vta;
              r_gmovi.cod_modulo    := v_mod_ori_vta;
              r_gmovi.cod_modalidad := v_mad_hij_vta;
              r_gmovi.mto_equ_local := abs(v_tot_mon_local);
              r_gmovi.cotizacion    := v_cot_venta;
              r_gmovi.cod_bco_central:= v_cod_tip_ope_bcp;
              r_gmovi.nro_documento := v_nro_operacion;
              r_gmovi.nro_documento2 := v_nro_ref_vta;
              r_gmovi.tip_mov_rubro  := 'C';
              r_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_vta;
              r_gmovi.cod_persona    := v_cod_persona;
              r_gmovi.emi_aviso     := 'N';
              v_lugar:='Ins.Movimiento 1';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-18;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
            --********* Generamos Movimiento 2---De la Cuenta de Cambios ************
            v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
            --- genera movimiento ---
            --recuperar datos de la cta de cambios
                 pag_cta.pr_obt_cuenta(v_cta_cambios);
                 v_est_cta_cam := pag_cta.g_ctas.estado;
                 v_cod_ofi_cta_cam := pag_cta.g_ctas.cod_oficina;
                 if pag_cta.fu_obt_cod_error() <> 0 then
                    v_lugar:='Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error();
                    v_respuesta:=-11;
                    raise_application_error(-20015,'Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error());
                 end if;
                 --solo si afecta límite
                 if v_afe_lim_vta <> 'S' THEN
                    v_lim_utilizado := 0;
                 else
                    --si moneda de la operación diferente al límite convertir
                    if v_cod_moneda <> v_mon_fuerte then
                       v_lim_utilizado:= pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_monto);--para q busque la correspondiente
                    else
                       v_lim_utilizado:= v_monto;
                    end if;
                 end if;
                 --actualización de límite, sólo si afecta recupera retención
                 begin
                 if nvl(v_afe_lim_vta,'N')='S' then
                   select estado, cod_oficina
                     into v_est_cta_cam, v_cod_ofi_cta_cam
                     from lc_cta_cambios
                    where nro_cuenta = v_cta_cambios
                      for update of estado;
                   update lc_cta_cambios
                      set mto_utilizado = nvl(mto_utilizado,0) + nvl(v_lim_utilizado,0),
                          fec_ult_movimiento = v_fec_actual,
                          estado = decode(estado,'A','N',estado),
                          fec_cam_estado =decode(estado,'A',v_fec_actual,fec_cam_estado)
                    where lc_cta_cambios.nro_cuenta = v_cta_cambios;
                   IF v_afe_lim_vta = 'S' THEN --solo si afecta límite
                      --obtiene retención
                      pal_cam.pr_obt_retencion(v_cod_tip_ope_vta, null, null,
                             v_mon_fuerte, v_cod_oficina,v_cod_retencion, v_fec_fin_retencion);
                   end if;
                 END IF;
                   --genera movimientos
                   --v_nro_secuencia         := v_nro_secuencia + 1;
                   r_gmovi.hora          := v_hora;
                   r_gmovi.cod_usuario   := v_cod_usuario;
                   r_gmovi.nro_secuencia   := v_nro_secuencia;
                   r_gmovi.cod_modulo      := 7;
                   r_gmovi.cod_modalidad   := 70;
                   r_gmovi.cod_oficina     := v_cod_ofi_cta_cam;
                   r_gmovi.cod_moneda      := v_mon_fuerte;
                   r_gmovi.cod_tra_padre   := v_cod_tra_ope_vta; --
                   r_gmovi.cod_transaccion := 760;
                   r_gmovi.monto           := NVL(v_lim_utilizado,0);
                   r_gmovi.nro_documento   := v_nro_operacion;
                   r_gmovi.COD_REF_CAMBIO := v_cod_tip_ref_vta;
                   r_gmovi.NRO_DOCUMENTO2  := v_cod_persona;
                   r_gmovi.REFERENCIA      := null;
                   r_gmovi.concepto        := 'Operación Cambios Límite';
                   r_gmovi.cod_rubro       := NULL;
                   r_gmovi.nro_cuenta      := v_cta_cambios;
                   r_gmovi.tip_mov_rubro   := null;
                   r_gmovi.cod_persona     := v_cod_persona;
                   if v_cod_moneda <> v_mon_fuerte then
                      r_gmovi.cotizacion   := pag_gen.fu_obt_cotizacion(v_mon_fuerte);--cotizacion del límite en la moneda fuerte
                   else
                      r_gmovi.cotizacion := v_cot_venta;
                   end if;
                   r_gmovi.mto_equ_local   := ROUND(NVL(v_lim_utilizado,0)*r_gmovi.cotizacion,v_redondeo_ml);
                   r_gmovi.cod_bco_central := v_cod_tip_ope_bcp;
                   r_gmovi.COD_RETENCION   := v_cod_retencion;
                   r_gmovi.FEC_FIN_RETENCION:= v_fec_fin_retencion;
                   r_gmovi.cod_tip_ope_cambio:= null;
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-19;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                   r_gmovi.referencia      := null;
                   v_cod_retencion         :=null;
                   v_fec_fin_retencion     :=null;
                   r_gmovi.COD_RETENCION   := v_cod_retencion;
                   r_gmovi.FEC_FIN_RETENCION:= v_fec_fin_retencion;
                   --movimiento x el cambio de estado de la cuenta si corresponde
                   if v_est_cta_cam = 'A' then
                      v_nro_secuencia := v_nro_secuencia + 1;
                      r_gmovi.nro_secuencia  := v_nro_secuencia;
                      r_gmovi.cod_modulo      := 7;
                      r_gmovi.cod_modalidad   := 70;
                      r_gmovi.cod_oficina     := v_cod_ofi_cta;
                      r_gmovi.cod_moneda      := v_mon_fuerte;
                      r_gmovi.fec_valor       := v_fec_actual;
                      r_gmovi.cod_tra_padre   := 401;
                      r_gmovi.cod_mod_padre   := 7;
                      r_gmovi.cod_mad_padre   := 70;
                      r_gmovi.cod_transaccion := 401;
                      r_gmovi.monto           := null;
                      r_gmovi.nro_documento   := null;
                      r_gmovi.NRO_DOCUMENTO2  := null;
                      r_gmovi.concepto        := 'Cambio de Estado ';
                      r_gmovi.est_cuenta      := 'N';
                      r_gmovi.cod_rubro       := NULL;
                      r_gmovi.nro_cuenta      := v_cta_cambios;
                      r_gmovi.tip_mov_rubro   := null;
                      r_gmovi.cotizacion      := null;
                      r_gmovi.mto_equ_local   := null;
                      r_gmovi.cod_bco_central := null;
                      r_gmovi.COD_RETENCION   := null;
                      r_gmovi.FEC_FIN_RETENCION :=null;
                      r_gmovi.COD_REF_CAMBIO   := null;
                      r_gmovi.cod_tip_ope_cambio := null;
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-20;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                    end if;
                  EXCEPTION
                    WHEN OTHERS THEN
                      v_respuesta:=-20;
                      raise_application_error(-20016,'Actualiza límite. '||sqlerrm);
                  END;
                   v_cod_retencion         :=null;
                   v_fec_fin_retencion     :=null;
                   r_gmovi.COD_RETENCION   := v_cod_retencion;
                   r_gmovi.FEC_FIN_RETENCION:= v_fec_fin_retencion;
         end if;
      --********* Generamos Movimiento 3---Cargo de Cambios 1 ************
        if nvl(v_mto_cargo1,0)>0 and v_respuesta=0 then
            v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
            v_mto_car_1:= nvl(v_mto_cargo1,0)-nvl(v_impuesto,0);
            --- genera movimiento ---
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.hora          := v_hora;
            r_gmovi.cod_usuario   := v_cod_usuario;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.fec_valor     := v_fec_actual;
            r_gmovi.monto         := v_mto_car_1;
            r_gmovi.nro_cuenta    := null;
            r_gmovi.cod_moneda    := v_mon_local;
            r_gmovi.cod_oficina   := v_cod_oficina;
            r_gmovi.estado        := v_est_mvto;
            r_gmovi.cod_ofi_origen:= v_cod_oficina;
            r_gmovi.concepto      := 'Cargos de Cambios';
            r_gmovi.cod_tasa      := v_cod_tasa_ini;
            r_gmovi.val_tasa      := v_mto_cargo1;
            r_gmovi.Cod_rubro     := NULL;
            r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
            r_gmovi.reversado     := 'N';
            r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
            r_gmovi.cod_mod_padre := v_mod_ori_vta;
            r_gmovi.cod_mad_padre := v_mad_hij_vta;
            r_gmovi.cod_transaccion:=v_cod_tra_cargo1;
            r_gmovi.cod_modulo    := v_mod_ori_vta;
            r_gmovi.cod_modalidad := v_mad_hij_vta;
            r_gmovi.mto_equ_local := NULL;
            r_gmovi.cotizacion    := NULL;
            r_gmovi.cod_bco_central:= NULL;
            r_gmovi.nro_documento := v_nro_operacion;
            r_gmovi.nro_documento2 := v_nro_ref_vta;
            r_gmovi.nro_documento3 := null;
            r_gmovi.nro_documento4 := null;
            r_gmovi.tip_mov_rubro  := null;
            r_gmovi.cod_tip_ope_cambio := null;
            r_gmovi.cod_persona    := v_cod_persona;
            r_gmovi.emi_aviso     := 'N';
            v_lugar:='Ins. Movimiento 3';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-21;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
            --********* Generamos Movimiento 4---Impuesto de Cambios 1 ************
            -- genero movimiento x el impuesto si no tiene exonerado
            if v_mov_impuesto is not null and nvl(v_val_tasa,0) <> 0 and v_respuesta=0 then
                  v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                  v_nro_secuencia         := v_nro_secuencia;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_transaccion := v_tra_impuesto;
                  r_gmovi.monto           := v_impuesto;
                  r_gmovi.COD_TASA        := v_cod_tasa;
                  r_gmovi.VAL_TASA        := v_val_tasa;
                  r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                  v_lugar:='Ins. Movimiento 4';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-22;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
            end if;
          end if;
          --********* Generamos Movimiento 5---Cargo de Cambios 2 ************
          if p_tip_cargo= 'OUR' and v_respuesta=0 AND NVL(v_mto_cargo2,0) >0 then
                v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                v_mto_car_2:= nvl(v_mto_cargo2,0)-nvl(v_impuesto1,0);
                --- genera movimiento ---
                r_gmovi.fecha         := v_fec_actual;
                r_gmovi.hora          := v_hora;
                r_gmovi.cod_usuario   := v_cod_usuario;
                r_gmovi.nro_secuencia := v_nro_secuencia;
                r_gmovi.fec_valor     := v_fec_actual;
                r_gmovi.monto         := v_mto_car_2;
                r_gmovi.nro_cuenta    := null;
                r_gmovi.cod_moneda    := v_mon_local;
                r_gmovi.cod_oficina   := v_cod_oficina;
                r_gmovi.estado        := v_est_mvto;
                r_gmovi.cod_ofi_origen:= v_cod_oficina;
                r_gmovi.concepto      := 'Cargo de Cambios';
                r_gmovi.cod_tasa      := v_cod_tasa_ini1;
                r_gmovi.val_tasa      := v_mto_cargo2;
                r_gmovi.Cod_rubro     := NULL;
                r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
                r_gmovi.reversado     := 'N';
                r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
                r_gmovi.cod_mod_padre := v_mod_ori_vta;
                r_gmovi.cod_mad_padre := v_mad_hij_vta;
                r_gmovi.cod_transaccion:=v_cod_tra_cargo2;
                r_gmovi.cod_modulo    := v_mod_ori_vta;
                r_gmovi.cod_modalidad := v_mad_hij_vta;
                r_gmovi.mto_equ_local := NULL;
                r_gmovi.cotizacion    := NULL;
                r_gmovi.cod_bco_central:= NULL;
                r_gmovi.nro_documento := v_nro_operacion;
                r_gmovi.nro_documento2 := v_nro_ref_vta;
                r_gmovi.nro_documento3 := null;
                r_gmovi.nro_documento4 := null;
                r_gmovi.tip_mov_rubro  := null;
                r_gmovi.cod_tip_ope_cambio := null;
                r_gmovi.cod_persona    := v_cod_persona;
                r_gmovi.emi_aviso     := 'N';
                v_lugar:='Ins. Movimiento 5';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-23;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
               --********* Generamos Movimiento 6---Impuesto de Cambios 2 ************
                v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;

                --DYDMR-2010: ITGF - Cargos cobrados y no facturados desde la WEB - SC 17247
                if v_mov_impuesto1 is not null and nvl(v_val_tasa1,0) <> 0 then
                      v_nro_secuencia         := v_nro_secuencia;
                      r_gmovi.nro_secuencia   := v_nro_secuencia;
                      r_gmovi.cod_transaccion := v_tra_impuesto1;
                      r_gmovi.monto           := v_mov_impuesto1;
                      r_gmovi.COD_TASA        := v_cod_tasa1;
                      r_gmovi.VAL_TASA        := v_val_tasa1;
                      r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                      v_lugar:='Ins.Movimiento 6';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-24;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                end if;
           end if;
         --********* Generamos Movimiento 7---Débito en Cta************
              --Calculamos el total en Guaranies
           if v_respuesta=0 then
              -- DYDMR-8959 NAF 12/2018
              if v_mov_impuesto != v_impuesto then
                 v_mto_car_1 := v_mto_cargo1 - v_impuesto;
              else
                 v_mto_car_1 := v_mto_cargo1;
              end if;
              if v_mov_impuesto1 != v_impuesto1 then
                 v_mto_car_2 := v_mto_cargo2 - v_impuesto1;
              else
                 v_mto_car_2 := v_mto_cargo2;
              end if;
               v_tot_gral:=nvl(abs(v_tot_mon_local),0)+nvl(v_mto_car_1,0)+nvl(v_mto_car_2,0);
               v_tot_gral:= ROUND(NVL(v_tot_gral,0),0);
               --v_respuesta:=-25;
                --v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;

                 pag_cta.pr_act_operacion(p_nro_cuenta,
                       v_hora,--HORA
                       'D',
                       v_cod_mon_cta, --Moneda de la Operación
                       v_tot_gral,
                       264,  -- COD_TRA_PADRE (venta divisas en efectivo)
                       503,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                       v_nro_operacion, --nro_documento
                       v_cot_venta,       --COTIZACION
                       v_cod_oficina,      --cod_ofi_origen
                       7,                --cod_mod_padre
                       72,    --o abmc.modalidad   --cod_mad_padre
                       null,                       --cod_tasa
                       null,                       --val_tasa
                       'Operación de Cambios '||v_nro_operacion,
                       'S',                        --emi_aviso
                       v_nro_secuencia,
                       v_fec_actual);
                        --Hacemos Update del Movimiento para igualar al CORE
                       IF nvl(v_es_noc,'N')='N' THEN
                          update ge_movimientos a
                          set a.cod_tip_ope_cambio=8
                             ,a.cod_persona= v_cod_persona
                             ,a.mto_equ_local=null
                             ,a.cod_modulo=v_cod_mod_cta
                             ,a.cod_modalidad=v_cod_moda_cta
                             ,a.cod_ref_cambio=v_cod_ref_cam_vta
                          where a.fecha=trunc(v_fec_actual)
                          and a.cod_usuario=v_cod_usuario
                          and a.hora=v_hora
                          and a.nro_documento=v_nro_operacion  
                          and a.cod_tra_padre=264
                          and a.cod_transaccion=503;
                       ELSE
                          update ge_movimientos_noc a
                          set a.cod_tip_ope_cambio=8
                             ,a.cod_persona= v_cod_persona
                             ,a.mto_equ_local=null
                             ,a.cod_modulo=v_cod_mod_cta
                             ,a.cod_modalidad=v_cod_moda_cta
                             ,a.cod_ref_cambio=v_cod_ref_cam_vta
                          where a.fecha=trunc(v_fec_actual)
                          and a.cod_usuario=v_cod_usuario
                          and a.hora=v_hora
                          and a.nro_documento=v_nro_operacion
                          and a.cod_tra_padre=264
                          and a.cod_transaccion=503;
                       END IF;

              end if;

elsif v_respuesta=0 then
  --***************OPERACION DE CANJE DE DIVISAS *******************************
           --asignar nro de recibo a la operación
           begin
             v_lugar:='Obt.Nro.Rec-CANJE';
             v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
             v_lugar:='Act.Par.Din.Nro.Rec-CANJE';
             prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_mon_cta, v_cod_oficina, v_nro_operacion);
           exception
              when others then
                 if sqlcode <= -20000 then
                   v_respuesta:=-17;
                    raise_application_error(-20012,'Asigna Nro.Oper. '||sqlerrm);
                 end if;
                 p_msj_error := substr(sqlerrm, 1, 200);
           end;
          v_lugar:='Obt.Cotiz-CANJE';
          v_cotizacion := p_cotizacion ;--pag_gen.FU_OBT_COTIZACION(v_cod_mon_cta,v_fec_actual);
          -- DYDMR-8959 NAF 12/2018
          if v_mov_impuesto != v_impuesto then
             v_mto_car_1 := v_mto_cargo1 - v_impuesto;
          else
             v_mto_car_1 := v_mto_cargo1;
          end if;
          if v_mov_impuesto1 != v_impuesto1 then
             v_mto_car_2 := v_mto_cargo2 - v_impuesto1;
          else
             v_mto_car_2 := v_mto_cargo2;
          end if;
          v_tot_gral:= nvl(v_monto,0) + nvl(v_mto_car_1,0) +  nvl(v_mto_car_2,0);
          v_lugar:='Obt.Par.Redondeo-CANJE';
          v_redondeo_me   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_cod_mon_cta);
          v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_tot_gral,v_redondeo_ml);
          v_cod_ref_cam_cpr:=6;
           --******* Generamos Movimiento 1 *******************
          --asigno nro_referencia, se utiliza secuencia para evitar bloqueos
          v_nro_secuencia:=0;
          if v_respuesta=0 then
              if v_cod_tip_ope_vta is not null then
                 v_lugar:='Obt.Sig.Secuencia';
                 v_nro_ref_vta := fue_obt_sig_secuencia('S_NRO_REF_'||lpad(v_cod_tip_ref_vta,3,0)||'');
              end if;
              v_hora := to_char(sysdate,'HH24:MI:SS');
              v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_noc);
              --v_respuesta:=-18;
                  ------------------------------------------
               -- Actualiza la Cuenta Débito / Destino
               v_lugar:='Act.Cta.Cliente-CANJE';
               v_tot_gral:= round(v_tot_gral,2);
                pag_cta.pr_act_operacion(p_nro_cuenta,
                 v_hora,--HORA
                 'D',
                 v_cod_mon_cta, --Moneda de la Operación
                 v_tot_gral,
                 288,  -- COD_TRA_PADRE (venta divisas en efectivo)
                 503,  -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                 v_nro_operacion, --nro_documento
                 v_cotizacion,       --COTIZACION
                 v_cod_oficina,      --cod_ofi_origen
                 7,                --cod_mod_padre
                 74,    --o abmc.modalidad   --cod_mad_padre
                 null,                       --cod_tasa
                 null,                       --val_tasa
                 'Transferencia al Exterior '||v_nro_operacion,
                 'N',                        --emi_aviso
                 v_nro_secuencia,
                 v_fec_actual);
                  --Hacemos Update del Movimiento para igualar al CORE
                  IF  nvl(v_es_noc,'N')='N' THEN
                      update ge_movimientos a
                      set a.cod_bco_central='A19'
                         ,a.cod_ref_cambio=v_cod_ref_cam_cpr
                         ,a.cod_tip_ope_cambio=91
                         ,a.cod_persona= v_cod_persona
                         ,a.mto_equ_local=v_tot_mon_local
                         ,a.cod_modulo=v_cod_mod_cta
                         ,a.cod_modalidad=v_cod_moda_cta
                         ,a.nro_documento2=v_nro_ref_vta
                      where a.fecha=trunc(v_fec_actual)
                      and a.cod_usuario=v_cod_usuario
                      and a.hora=v_hora
                      and a.nro_documento=v_nro_operacion  --DYDMR-5290 Nov/2016
                      and a.cod_tra_padre=288
                      and a.cod_transaccion=503;
                 ELSE
                      update ge_movimientos_noc a
                      set a.cod_bco_central='A19'
                           ,a.cod_ref_cambio=v_cod_ref_cam_cpr
                           ,a.cod_tip_ope_cambio=91
                           ,a.cod_persona= v_cod_persona
                           ,a.mto_equ_local=v_tot_mon_local
                           ,a.cod_modulo=v_cod_mod_cta
                           ,a.cod_modalidad=v_cod_moda_cta
                           ,a.nro_documento2=v_nro_ref_vta
                       where a.fecha=trunc(v_fec_actual)
                       and a.cod_usuario=v_cod_usuario
                       and a.hora=v_hora
                       and a.nro_documento=v_nro_operacion
                       and a.cod_tra_padre=288
                       and a.cod_transaccion=503;
                 END IF;
          end if;
          --********* Generamos Movimiento 2--************
          if v_respuesta =0 then
          v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
          v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * abs(v_monto),v_redondeo_ml);
          --- genera movimiento ---
          r_gmovi.fecha         := v_fec_actual;
          r_gmovi.hora          := v_hora;
          r_gmovi.cod_usuario   := v_cod_usuario;
          r_gmovi.nro_secuencia := v_nro_secuencia;
          r_gmovi.fec_valor     := v_fec_actual;
          r_gmovi.monto         := abs(v_monto);
          r_gmovi.nro_cuenta    := NULL;
          r_gmovi.cod_moneda    := v_cod_moneda;
          r_gmovi.cod_oficina   := v_cod_oficina;
          r_gmovi.estado        := v_est_mvto;
          r_gmovi.cod_ofi_origen:= v_cod_oficina;
          r_gmovi.concepto      := 'TTE';
          r_gmovi.cod_tasa      := null;
          r_gmovi.val_tasa      := null;
          r_gmovi.Cod_rubro     := v_cod_rub_ope;
          r_gmovi.cod_ref_cambio:= v_cod_ref_cam_vta;
          r_gmovi.reversado     := 'N';
          r_gmovi.cod_tra_padre := v_cod_tra_ope_vta;
          r_gmovi.cod_mod_padre := v_mod_ori_vta;
          r_gmovi.cod_mad_padre := 74;
          r_gmovi.cod_transaccion:=v_cod_tra_ope_vta;
          r_gmovi.cod_modulo    := v_mod_ori_vta;
          r_gmovi.cod_modalidad := v_mad_hij_vta;
          r_gmovi.mto_equ_local := abs(v_tot_mon_local);
          r_gmovi.cotizacion    := v_cotizacion;
          r_gmovi.cod_bco_central:= v_cod_tip_ope_bcp;
          r_gmovi.nro_documento := v_nro_operacion;
          r_gmovi.nro_documento2 := v_nro_ref_vta;
          r_gmovi.tip_mov_rubro  := 'C';
          r_gmovi.cod_tip_ope_cambio := v_cod_tip_ope_vta;
          r_gmovi.cod_persona    := v_cod_persona;
          r_gmovi.emi_aviso     := 'N';
          v_lugar:='Ins Movimiento 2-CANJE';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-19;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
          --********* Generamos Movimiento 3---De la Cuenta de Cambios ************
          v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
          --- genera movimiento ---
          --recuperar datos de la cta de cambios
               pag_cta.pr_obt_cuenta(v_cta_cambios);
               v_est_cta_cam := pag_cta.g_ctas.estado;
               v_cod_ofi_cta_cam := pag_cta.g_ctas.cod_oficina;
               if pag_cta.fu_obt_cod_error() <> 0 then
                  v_respuesta:=-11;
                  raise_application_error(-20015,'Recup.Cta.Cambios '||v_cta_cambios||'-'||pag_cta.fu_obt_msj_error());
               end if;
               --solo si afecta límite
               if v_afe_lim_vta <> 'S' THEN
                  v_lim_utilizado := 0;
               else
                  --si moneda de la operación diferente al límite convertir
                  if v_cod_moneda <> v_mon_fuerte then
                     v_lim_utilizado:= pal_cam.FU_CON_MON_A_MONEDA(v_cod_moneda,v_mon_fuerte,v_monto);--para q busque la correspondiente
                  else
                     v_lim_utilizado:= v_monto;
                  end if;
               end if;
               --actualización de límite, sólo si afecta recupera retención
               begin
               if nvl(v_afe_lim_vta,'N')='S' and v_respuesta=0 then
                 select estado, cod_oficina
                   into v_est_cta_cam, v_cod_ofi_cta_cam
                   from lc_cta_cambios
                  where nro_cuenta = v_cta_cambios
                    for update of estado;
                 update lc_cta_cambios
                    set mto_utilizado = nvl(mto_utilizado,0) + nvl(v_lim_utilizado,0),
                        fec_ult_movimiento = v_fec_actual,
                        estado = decode(estado,'A','N',estado),
                        fec_cam_estado =decode(estado,'A',v_fec_actual,fec_cam_estado)
                  where lc_cta_cambios.nro_cuenta = v_cta_cambios;
                 IF v_afe_lim_vta = 'S' THEN --solo si afecta límite
                    --obtiene retención
                    pal_cam.pr_obt_retencion(v_cod_tip_ope_vta, null, null,
                           v_mon_fuerte, v_cod_oficina,v_cod_retencion, v_fec_fin_retencion);
                 end if;
               END IF;
                 --genera movimientos
                 r_gmovi.hora          := v_hora;
                 r_gmovi.cod_usuario   := v_cod_usuario;

                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 r_gmovi.cod_modulo      := 7;
                 r_gmovi.cod_modalidad   := 70;
                 r_gmovi.cod_oficina     := v_cod_ofi_cta_cam;
                 r_gmovi.cod_moneda      := v_mon_fuerte;
                 r_gmovi.cod_tra_padre   := 288; --
                 r_gmovi.cod_transaccion := 760;
                 r_gmovi.monto           := v_lim_utilizado;
                 r_gmovi.nro_documento   := v_nro_operacion;
                 r_gmovi.COD_REF_CAMBIO := v_cod_ref_cam_cpr;
                 r_gmovi.NRO_DOCUMENTO2  := v_cod_persona;
                 r_gmovi.REFERENCIA      := null;
                 r_gmovi.concepto        := 'Operación Cambios Límite';
                 r_gmovi.cod_rubro       := NULL;
                 r_gmovi.nro_cuenta      := v_cta_cambios;
                 r_gmovi.tip_mov_rubro   := null;
                 r_gmovi.cod_persona     := v_cod_persona;
                 if v_cod_moneda <> v_mon_fuerte then
                    r_gmovi.cotizacion   := pag_gen.fu_obt_cotizacion(v_mon_fuerte);--cotizacion del límite en la moneda fuerte
                 else
                    r_gmovi.cotizacion := v_cotizacion;
                 end if;
                 r_gmovi.mto_equ_local   := ROUND(NVL(v_lim_utilizado,0)*r_gmovi.cotizacion,v_redondeo_ml);
                 r_gmovi.cod_bco_central := 'A19';
                 r_gmovi.COD_RETENCION   := v_COD_RETENCION;
                 r_gmovi.FEC_FIN_RETENCION:= v_FEC_FIN_RETENCION;
                 r_gmovi.cod_tip_ope_cambio:= null;
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-19;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                 r_gmovi.REFERENCIA      := null;
                 --movimiento x el cambio de estado de la cuenta si corresponde
                 if v_est_cta_cam = 'A' then
                    v_nro_secuencia := v_nro_secuencia + 1;
                    r_gmovi.nro_secuencia  := v_nro_secuencia;
                    r_gmovi.cod_modulo      := 7;
                    r_gmovi.cod_modalidad   := 70;
                    r_gmovi.cod_oficina     := v_cod_ofi_cta;
                    r_gmovi.cod_moneda      := v_mon_fuerte;
                    r_gmovi.fec_valor       := v_fec_actual;
                    r_gmovi.cod_tra_padre   := 401;
                    r_gmovi.cod_mod_padre   := 7;
                    r_gmovi.cod_mad_padre   := 70;
                    r_gmovi.cod_transaccion := 401;
                    r_gmovi.monto           := null;
                    r_gmovi.nro_documento   := null;
                    r_gmovi.NRO_DOCUMENTO2  := null;
                    r_gmovi.concepto        := 'Cambio de Estado ';
                    r_gmovi.est_cuenta      := 'N';
                    r_gmovi.cod_rubro       := NULL;
                    r_gmovi.nro_cuenta      := v_cta_cambios;
                    r_gmovi.tip_mov_rubro   := null;
                    r_gmovi.cotizacion      := null;
                    r_gmovi.mto_equ_local   := null;
                    r_gmovi.cod_bco_central := null;
                    r_gmovi.COD_RETENCION   := null;
                    r_gmovi.FEC_FIN_RETENCION :=null;
                    r_gmovi.COD_REF_CAMBIO   := null;
                    r_gmovi.cod_tip_ope_cambio := null;
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-20;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                  end if;
                EXCEPTION
                  WHEN OTHERS THEN
                    v_respuesta:=-20;
                    raise_application_error(-20016,'Actualiza límite. '||sqlerrm);
                END;
                 v_cod_retencion         :=null;
                 v_fec_fin_retencion     :=null;
                 r_gmovi.COD_RETENCION   := v_cod_retencion;
                 r_gmovi.FEC_FIN_RETENCION:= v_fec_fin_retencion;
           end if;
           --********* Generamos Movimiento 4---Cargo de Cambios 1 ************
           if nvl(v_mto_cargo1,0)>0 and v_respuesta=0 then
                v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                v_mto_car_1:= nvl(v_mto_cargo1,0)-nvl(v_impuesto,0);
                v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_mto_car_1,v_redondeo_ml);
                --- genera movimiento ---
                r_gmovi.fecha         := v_fec_actual;
                r_gmovi.hora          := v_hora;
                r_gmovi.cod_usuario   := v_cod_usuario;
                r_gmovi.nro_secuencia := v_nro_secuencia;
                r_gmovi.fec_valor     := v_fec_actual;
                r_gmovi.monto         := v_mto_car_1;
                r_gmovi.nro_cuenta    := null;
                r_gmovi.cod_moneda    := v_cod_moneda;
                r_gmovi.cod_oficina   := v_cod_oficina;
                r_gmovi.estado        := v_est_mvto;
                r_gmovi.cod_ofi_origen:= v_cod_oficina;
                r_gmovi.concepto      := 'Cargos de Cambios';
                r_gmovi.cod_tasa      := v_cod_tasa_ini;
                r_gmovi.val_tasa      := v_mto_cargo1;
                r_gmovi.Cod_rubro     := NULL;
                r_gmovi.cod_ref_cambio:= v_cod_ref_cam_cpr;
                r_gmovi.reversado     := 'N';
                r_gmovi.cod_tra_padre := 288;
                r_gmovi.cod_mod_padre := v_mod_ori_vta;
                r_gmovi.cod_mad_padre := 74;
                r_gmovi.cod_transaccion:=v_cod_tra_cargo1;
                r_gmovi.cod_modulo    := v_mod_ori_vta;
                r_gmovi.cod_modalidad := 74;
                r_gmovi.mto_equ_local := v_tot_mon_local;
                r_gmovi.cotizacion    := v_cotizacion;
                r_gmovi.cod_bco_central:= NULL;
                r_gmovi.nro_documento := v_nro_operacion;
                r_gmovi.nro_documento2 := v_nro_ref_vta;
                r_gmovi.nro_documento3 := null;
                r_gmovi.nro_documento4 := null;
                r_gmovi.tip_mov_rubro  := null;
                r_gmovi.cod_tip_ope_cambio := null;
                r_gmovi.cod_persona    := v_cod_persona;
                r_gmovi.emi_aviso     := 'N';

                v_lugar:='Ins Movimiento 4-CANJE';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-22;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                --********* Generamos Movimiento 5---Impuesto de Cambios 1 ************
                -- genero movimiento x el impuesto si no tiene exonerado
                v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_impuesto,v_redondeo_ml);
                if v_mov_impuesto is not null and nvl(v_val_tasa,0) <> 0 and v_respuesta=0 then
                      v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                      v_nro_secuencia         := v_nro_secuencia;
                      r_gmovi.nro_secuencia   := v_nro_secuencia;
                      r_gmovi.cod_transaccion := v_tra_impuesto;
                      r_gmovi.monto           := v_impuesto;
                      r_gmovi.COD_TASA        := v_cod_tasa;
                      r_gmovi.VAL_TASA        := v_val_tasa;
                      r_gmovi.mto_equ_local   := v_tot_mon_local;
                      r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                      v_lugar:='Ins Movimiento 5-CANJE';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-23;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                end if;
             end if;
          --********* Generamos Movimiento 6---Cargo de Cambios 2 ************
          if p_tip_cargo= 'OUR' and v_respuesta=0 AND NVL(v_mto_cargo2,0) >0 then
                v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                v_mto_car_2:= nvl(v_mto_cargo2,0)-nvl(v_impuesto1,0);
                v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_mto_car_2,v_redondeo_ml);
                --- genera movimiento ---
                r_gmovi.fecha         := v_fec_actual;
                r_gmovi.hora          := v_hora;
                r_gmovi.cod_usuario   := v_cod_usuario;
                r_gmovi.nro_secuencia := v_nro_secuencia;
                r_gmovi.fec_valor     := v_fec_actual;
                r_gmovi.monto         := v_mto_car_2;
                r_gmovi.nro_cuenta    := null;
                r_gmovi.cod_moneda    := v_cod_moneda;
                r_gmovi.cod_oficina   := v_cod_oficina;
                r_gmovi.estado        := v_est_mvto;
                r_gmovi.cod_ofi_origen:= v_cod_oficina;
                r_gmovi.concepto      := 'Cargo de Cambios';
                r_gmovi.cod_tasa      := v_cod_tasa_ini1;
                r_gmovi.val_tasa      := v_mto_cargo2;
                r_gmovi.Cod_rubro     := NULL;
                r_gmovi.cod_ref_cambio:= v_cod_ref_cam_cpr;
                r_gmovi.reversado     := 'N';
                r_gmovi.cod_tra_padre := 288;
                r_gmovi.cod_mod_padre := v_mod_ori_vta;
                r_gmovi.cod_mad_padre := 74;
                r_gmovi.cod_transaccion:=v_cod_tra_cargo2;
                r_gmovi.cod_modulo    := v_mod_ori_vta;
                r_gmovi.cod_modalidad := 74;
                r_gmovi.mto_equ_local := v_tot_mon_local;
                r_gmovi.cotizacion    := v_cotizacion;
                r_gmovi.cod_bco_central:= NULL;
                r_gmovi.nro_documento := v_nro_operacion;
                r_gmovi.nro_documento2 := v_nro_ref_vta;--vERIFICAR
                r_gmovi.nro_documento3 := null;
                r_gmovi.nro_documento4 := null;
                r_gmovi.tip_mov_rubro  := null;
                r_gmovi.cod_tip_ope_cambio := null;
                r_gmovi.cod_persona    := v_cod_persona;
                r_gmovi.emi_aviso     := 'N';
                v_lugar:='Ins Movimiento 6-CANJE';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-24;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
               --********* Generamos Movimiento 7---Impuesto de Cambios 2 ************
                v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                 v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_mov_impuesto1,v_redondeo_ml);
                --DYDMR-2010: ITGF - Cargos cobrados y no facturados desde la WEB - SC 17247
                if v_mov_impuesto1 is not null and nvl(v_val_tasa1,0) <> 0 and v_respuesta=0 then
                      v_nro_secuencia         := v_nro_secuencia;
                      r_gmovi.nro_secuencia   := v_nro_secuencia;
                      r_gmovi.cod_transaccion := v_tra_impuesto1;
                      r_gmovi.monto           := v_mov_impuesto1;
                      r_gmovi.COD_TASA        := v_cod_tasa1;
                      r_gmovi.VAL_TASA        := v_val_tasa1;
                      r_gmovi.concepto        := 'Impuesto Cargos de Cambios';
                      r_gmovi.mto_equ_local   := v_tot_mon_local;
                      v_lugar:='Ins Movimiento 7-CANJE';
                  begin
                    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_noc);
                  exception
                    when others then
                      v_respuesta:=-25;
                      p_msj_error := substr(sqlerrm, 1, 200);
                  end;
                end if;
          end if;
 end if;
end if;

if  p_nro_prepactada is not null and v_respuesta=0 then
   begin
   --v_respuesta:=-29;
      --Se pasa a liquidada la Operación Prepactada (Venta)
      
     
      if v_can_ope > 1 then
         --Se liquida la Operación 2 de compra
         update lc_ope_pen_cambios a
            set a.liquidado='S', 
                a.cod_usu_liquidacion = user,
                a.fec_liquidacion = trunc(sysdate)
          where a.liquidado='N'
            and a.ope_homebanking = 'S'
            and a.nro_diario = p_nro_prepactada
            and trunc(a.fec_operacion)=trunc(sysdate);
      else
         update lc_ope_pendientes a
            set a.liquidado='S',
                a.cod_usu_liquidacion = user,
                a.fec_liquidacion = trunc(sysdate)
          where a.liquidado='N'
            --and a.nro_operacion= p_nro_prepactada
            and a.nro_diario = p_nro_prepactada
            and a.ope_homebanking = 'S'
            and trunc(a.fec_operacion)=trunc(sysdate);
      end if;
   exception
      when others then
         v_respuesta := -29;
         p_msj_error := substr(sqlerrm, 1, 200);
   end;
end if;


p_respuesta:=v_respuesta;
if p_respuesta=0 then
 p_nro_documento:= nvl(v_nro_operacion, v_nro_operacion2);
 p_nro_documento2:=v_nro_operacion2;
end if;
EXCEPTION
  when too_many_rows then
    p_respuesta:= -30;
    RAISE_APPLICATION_ERROR( -20000, 'Mas de Una fila Recuperada: '||v_lugar);
  when others then
    p_respuesta:= v_respuesta;
    RAISE_APPLICATION_ERROR( -20000, 'Error: '||v_lugar||'- '||sqlerrm);

END;

--
PROCEDURE PR_OBT_TOT_TRA_HB
(p_nro_cuenta       in varchar2 default null,
p_cod_mon_tra       in varchar2,     --Moneda Transferencia
p_plazo             in number,       --Plazo de La Transferencia
p_monto             in number default null, --Monto de la Transferencia
p_nro_prepactada    in number default null, --Nro de Operación Pre-pactada
p_tip_cargo         in varchar2, --'OUR'/'BEN'
p_exonerado         in varchar2, -- 'S'/'N'
--Para intermediario
p_cod_bco_cor_contra  in lc_transferencias.cod_bco_cor_contra%type default null,
p_nom_bco_cor_contra  in lc_transferencias.nom_bco_cor_contra%type default null,
p_cod_swi_bco_contra  in lc_transferencias.cod_swi_bco_contra%type default null,
p_cod_pai_bco_contra  in lc_transferencias.cod_pai_bco_contra%type default null,
p_cod_ciu_bco_contra  in lc_transferencias.cod_ciu_bco_contra%type default null,
--
p_importe           out number, --Importe de la Operación
p_cargo             out number, --Importe del Cargo
p_cotizacion        out number, --Cotización de Moneda de Transferencia
p_cot_contra        out number, --Cotización de Moneda de contra partida
p_cod_tra_padre     out varchar2, --Transaccion Padre
p_fec_operacion     out date, --Fecha de Operación
p_fec_valor         out date, --Fecha de Valor
p_cod_tip_operacion out varchar2, -- codigo de operacion de venta/canje
p_respuesta         out number --Respuesta 0 sino hubo errores, sino Error
)
IS
v_fec_actual        date := pag_cal.fu_obt_fec_actual(9);
v_cod_oficina       ge_movimientos.cod_oficina%type;
v_tot_mon_local     ge_movimientos.monto%type;
v_tot_mon_local_vta ge_movimientos.monto%type;
v_tot_mon_compra    ge_movimientos.monto%type;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_ope_vta   lc_tip_operaciones.cod_tip_operacion%type;
v_cod_tip_ope_cpra  lc_tip_operaciones.cod_tip_operacion%type;
v_nro_operacion     ge_movimientos.nro_documento%type;
v_nro_ope_compra    ge_movimientos.nro_documento%type;
v_cod_persona       ge_movimientos.cod_persona%type;
v_cta_referencia    ge_movimientos.cod_rubro%type;
v_mto_cargo1        lc_ope_pendientes.mto_cargo1%type;
v_mto_cargo2        lc_ope_pendientes.mto_cargo2%type;
v_mto_contra4       lc_ope_pendientes.mto_contra4%type;
v_cta_ref_contra4   lc_ope_pendientes.cta_ref_contra4%type;
v_cta_ref_contra3   lc_ope_pendientes.cta_ref_contra4%type;
v_nro_cuenta        lc_ope_pendientes.nro_cuenta%type;
v_cta_cambios       lc_ope_pendientes.nro_cuenta%type;
v_cod_mon_cta       ge_movimientos.cod_moneda%type default null;
v_cod_moneda        lc_transferencias.cod_moneda%type;
v_monto             lc_transferencias.monto%type;
v_afe_pos_cpra      lc_tip_operaciones.afe_posicion%type;
v_afe_lim_cpra      lc_tip_operaciones.afe_limite%type;
v_caj_cpra          lc_tip_operaciones.caja%type;
v_tip_val_cpra      lc_tip_operaciones.tip_valor%type;
v_mod_ori_cpra      lc_tip_operaciones.cod_mod_origen%type;
v_mad_hij_cpra      lc_tip_operaciones.cod_mad_hijo%type;
v_cod_tra_ope_cpra  lc_tip_operaciones.cod_transaccion%type;
v_cod_tra_cargo1    lc_tip_operaciones.cod_tra_cargo1%type;
v_cod_tra_cargo2    lc_tip_operaciones.cod_tra_cargo2%type;
v_cod_tra_cargo3    lc_tip_operaciones.cod_tra_cargo3%type;
v_tip_apl_cpra      lc_tip_ope_oficinas.tip_aplicacion%type;
v_cod_rub_cpra      lc_tip_ope_oficinas.cod_rubro%type;
v_cod_tip_ref_cpra  lc_tip_ope_oficinas.cod_tip_referencia%type;
v_des_ope_cpra      lc_tip_operaciones.descripcion%type;
v_ope_bcp_cpra      lc_tip_operaciones.cod_tip_ope_bcp%type;
v_cot_compra        ge_cotizaciones.val_conversion%type;
v_cot_venta         ge_cotizaciones.val_conversion%type;
v_des_cargo         ge_transacciones.descripcion%type;
v_afe_pos_vta       lc_tip_operaciones.afe_posicion%type;
v_afe_lim_vta       lc_tip_operaciones.afe_limite%type;
v_caj_vta           lc_tip_operaciones.caja%type;
v_tip_val_vta       lc_tip_operaciones.tip_valor%type;
v_mod_ori_vta       lc_tip_operaciones.cod_mod_origen%type;
v_mad_hij_vta       lc_tip_operaciones.cod_mad_hijo%type;
v_cod_tra_ope_vta   lc_tip_operaciones.cod_transaccion%type;
v_tip_apl_vta       lc_tip_ope_oficinas.tip_aplicacion%type;
v_cod_rub_vta       lc_tip_ope_oficinas.cod_rubro%type;
v_cod_tip_ope_pre   lc_ope_pendientes.cod_tip_operacion%type;
v_cod_tip_ref_vta   lc_tip_ope_oficinas.cod_tip_referencia%type;
v_des_ope_vta       lc_tip_operaciones.descripcion%type;
v_ope_bcp_vta       lc_tip_operaciones.cod_tip_ope_bcp%type;
v_mad_operacion     lc_transferencias.cod_modalidad%type;
v_mon_local         ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
v_cod_ofi_cta       lc_cta_cambios.cod_oficina%type;
v_tra_impuesto      ge_movimientos.cod_transaccion%type;
v_tra_impuesto1     ge_movimientos.cod_transaccion%type;
v_impuesto          ge_movimientos.monto%type;
v_impuesto1         ge_movimientos.monto%type;
v_mov_impuesto      ge_movimientos.monto%type;
v_mov_impuesto1     ge_movimientos.monto%type;
v_cod_tasa          ge_movimientos.cod_tasa%type;
v_val_tasa          ge_movimientos.val_tasa%type;
v_cod_tasa1         ge_movimientos.cod_tasa%type;
v_val_tasa1         ge_movimientos.val_tasa%type;
v_redondeo_ml       number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,v_mon_local);
v_redondeo_me       number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,p_cod_mon_tra);
v_equ_venta         ge_movimientos.mto_equ_local%type;
v_nom_cliente       ge_movimientos.concepto%type;
v_can_ope           number(3):=1;
v_nro_doc_cliente   ba_personas.nro_documento%type;
v_tot_gral          ge_movimientos.monto%type;
v_lugar             varchar2(1000):=null;
v_tipo              varchar2(10);
v_cod_ref_cam_vta   ge_movimientos.cod_ref_cambio%type;
v_cod_ref_cam_cpr   ge_movimientos.cod_ref_cambio%type;
v_respuesta         number:=0;
v_fec_operacion     lc_transferencias.fec_operacion%type;
v_fec_valor         lc_transferencias.fec_valor%type;
v_hor_corte         ge_par_dinamicos.val_parametro%type:=nvl(fug_obt_pardinamico('HOR_COR_TTE',null,null,p_cod_mon_tra),fug_obt_pardinamico('HOR_COR_TTE',null,null,'USD'));
v_fec_hor_corte     date;
v_fec_hor_actual    date;
v_cantidad          number default 0;
v_existe          number default 0;
v_cod_banco_int     lc_transferencias.cod_bco_cor_contra%type;
v_cta_referencia_cre lc_ope_pendientes.cta_referencia%type;
v_imp_personalizado  ge_movimientos.monto%type; -- DYDMR-5780 05/2018 NAF
v_imp_personalizado1  ge_movimientos.monto%type;
v_cod_modalidad     lc_tip_operaciones.cod_modalidad%type;
/* Listado de respuestas posibles
0   'Ok'
-1  'TTE habilitado para Euros y Dólares'
-2  'Monto de Operación debe ser mayor a Cero'
-3  'El tipo de Cargo debe ser OUR o BEN'
-4  'Plazo debe ser 0(0 horas)/1(24 horas)/2(48 horas)'
-5  'Obtener Cta de Débito'
-6  'No se encuentra Op. de Venta Prepactada'
-7  'La Moneda de la Transf. y de la Operac.Prepactada son distintas'
-8  'El Monto de la Transf. y de la Operac.Prepactada son distintos'
-9  'No se encuentra Op. de Compra Prepactada '
-10 'El Nro de Cuenta de la Transf. y de la Operac.Prepactada son distintas'
-11 'Al Obt.Cta.Limite de Cambios'
-12 'Tipo de Operación inválida'
-13 'Recuperar Cargo Inicial a Cobrar'
-14 'Recuperar Impuesto Inicial a Cobrar'
-15 'Recuperar Cargo Posterior a Cobrar'
-16 'Recuperar Impuesto Posterior a Cobrar'
-17 'Mas de una Fila Recuperada'
-31 'Plazo de Pre-Pactada no coincide con el plazo de la Transferencia'
-33 'No coincide Cargo de Prepactada con HB'

-34  'Banco Intermediario Inexistente'
-35 'Pais de Banco del Intermediario no corresponde'
-36 'Ciudad de Banco del Intermediario no corresponde'
*/
/**** Recupera Cta de Cambios del Cliente */
FUNCTION lf_obt_cta_cliente RETURN varchar2 IS
v_nro_cuenta lc_cta_cambios.nro_cuenta%type;
BEGIN
  SELECT B.NRO_CUENTA
    INTO v_nro_cuenta
    FROM LC_CTA_CAMBIOS B, GE_CTA_CLIENTES  A
   WHERE ESTADO in('N','A')
     AND A.NRO_CUENTA = B.NRO_CUENTA
     AND RELACION = 'P'
     AND A.COD_MODULO = 7
     AND A.COD_MODALIDAD = 70
     AND A.COD_PERSONA = v_cod_persona
     AND ROWNUM = 1;--en teoria debe haber un solo límite x cliente,siempre en USD
   return v_nro_cuenta;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
       --recuperar par dinamico para cuenta bolsa x la oficina
       v_nro_cuenta:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_ofi_cta);
       return v_nro_cuenta;
  WHEN OTHERS THEN
        v_respuesta:=-12;
  END;
--Funcion que Obtiene la Cotización para el HB
FUNCTION LF_OBT_COT_HB(p_cod_moneda IN VARCHAR2,p_tipo in varchar) RETURN number IS
v_cotizacion ge_cotizaciones.val_ven_electronica%type;
BEGIN
         SELECT decode(p_tipo,'VEN',a.val_ven_electronica,a.val_com_electronica )
           into v_cotizacion
           FROM ba_monedas c, ge_cotizaciones a
          WHERE a.cod_moneda = p_cod_moneda
            AND a.cod_moneda = c.cod_moneda
            AND fecha = (SELECT MAX(fecha)
                           FROM ge_cotizaciones b
                          WHERE b.cod_moneda = a.cod_moneda);
     return v_cotizacion;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
      null;
  WHEN OTHERS THEN
       null;
END;


begin
      ---**************INICIO DE PROCESO PRINCIPAL ****************************************
      --Solo se trabajará con Usd y Euros
      if p_cod_mon_tra not in ('USD','EUR') then
        v_respuesta:=-1;
      end if;
      if nvl(p_monto,0)<=0 then
        v_respuesta:=-2;
      end if;
      if p_tip_cargo not in ('OUR','BEN') then
         v_respuesta:=-3 ;
      end if;
        --Validamos Plazo
       if p_plazo not in (0,1,2) then
         v_respuesta:=-4;
       end if;

       --Verificamos el Banco Intermediario(Opcional)
       --si es nulo asignamos 999
       if p_cod_bco_cor_contra is null then
         v_cod_banco_int:=999;
       else
         v_cod_banco_int:=p_cod_bco_cor_contra;
       end if;
       if v_cod_banco_int is not null and v_respuesta=0 then
          v_cantidad:=0;
          begin
            SELECT count(*)
               into v_cantidad
                 FROM GE_BANCOS a
                  where a.estado ='A'
                   and a.ubicacion = 'E'
                   and a.cod_banco=v_cod_banco_int;
          exception
            when no_data_found then
              v_cantidad:=0;
            when others then
              v_cantidad:=0;
          end;
          if nvl(v_cantidad,0)=0 and v_respuesta=0 then
               v_respuesta:=-34;
          end if;
          --Validamos el Pais del Banco Intermediario
          if p_cod_pai_bco_contra is not null then
            v_existe:=0;
            begin
              select count(*)
                 into v_existe
                  from ba_paises a
                   where a.cod_pais=p_cod_pai_bco_contra;
            exception
              when no_data_found then
                v_existe:=0;
              when others then
                v_existe:=0;
            end;
             if  v_existe =0 then
                v_respuesta:=-35;
             end if;

          end if;
           --Validamos la ciudad del Banco Intermediario
          if p_cod_ciu_bco_contra is not null then
            v_existe:=0;
            begin
              select count(*)
                 into v_existe
                  from ba_ciudades a
                   where a.cod_ciudad=p_cod_ciu_bco_contra;
            exception
              when no_data_found then
                v_existe:=0;
              when others then
                v_existe:=0;
            end;
             if  v_existe =0 then
                v_respuesta:=-36;
             end if;

          end if;

       end if;

IF v_respuesta=0 THEN
      -- para NLS B.D.
      PRE_CAM_FOR_NUMERICO('.,');
      begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
      v_can_ope:=1;
      -- *********Obtenemos los datos de la Cuenta *******
      if p_nro_cuenta is not null then
          v_lugar:='Obt.Datos Cta.Cli.';
          pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
              if pag_cta.fu_obt_cod_error() <> 0 then
                 v_lugar:='Obt.Datos Cta.Cli.'||p_nro_cuenta||'-'||pag_cta.fu_obt_msj_error();
                 v_respuesta:=-5;
              end if;
                  --Datos Cta
                  v_cod_mon_cta := pag_cta.FU_OBT_MON_CUENTA;
                  v_cod_ofi_cta  := pag_cta.g_ctas.cod_oficina;
              v_lugar:='Obt. Datos de Persona x Cta';
              IF v_respuesta=0 THEN
                  begin
                    select a.cod_persona,b.nom_completo,b.nro_documento
                     into  v_cod_persona, v_nom_cliente,v_nro_doc_cliente
                      from ge_cta_clientes a, ba_personas b
                       where a.cod_persona=b.cod_persona
                        and a.nro_cuenta= p_nro_cuenta
                        and a.relacion='P';
                  exception
                    when no_data_found then
                        v_cod_persona:= null;
                        v_nro_doc_cliente:=null;
                    when others then
                        v_cod_persona:= null;
                        v_nro_doc_cliente:=null;
                  end;
              END IF;
      end if;
      v_tipo:=null;
      --Si la Moneda de la Cta es Distinto de la de la Transferencia 2 Operaciones
      --Y no es moneda Local
      if v_respuesta = 0 then
         lp_obt_ope_cambio(v_cod_mon_cta, p_cod_mon_tra, p_plazo,
                           -- variables salida
                           v_can_ope, v_cod_tip_ope_vta, v_cod_tip_ope_cpra, v_tipo);
      end if;

       --****** Si viene como prepactada *********************
      if v_respuesta=0 then
         if p_nro_prepactada is not null  then
            --Tiene prepactada- Retomamos la operación Prepactada de Venta Transferencia
            v_lugar:='Obt.Ope.Prep.Venta';
            Begin
               if v_can_ope <> 2 then  
                  select nro_operacion,
                         a.cod_moneda, a.cod_persona, cod_oficina, monto, cotizacion,mto_equ_local,
                         cta_referencia, cod_tra_cargo1, mto_cargo1, cod_tra_cargo2,
                         mto_cargo2, cta_ref_contra4, mto_contra4, nro_cuenta, a.cod_tip_operacion,
                         cta_ref_contra3
                    into v_nro_operacion,
                         v_cod_moneda, v_cod_persona,v_cod_oficina, v_monto,v_cotizacion,v_tot_mon_local_vta,
                         v_cta_referencia, v_cod_tra_cargo1,v_mto_cargo1 ,v_cod_tra_cargo2,
                         v_mto_cargo2,v_cta_ref_contra4,v_mto_contra4,v_cta_cambios,v_cod_tip_ope_pre,
                         v_cta_ref_contra3
                    from ba_monedas c, ba_personas b, lc_ope_pendientes a
                   where nro_diario=p_nro_prepactada
                     and b.cod_persona(+) = a.cod_persona
                     and c.cod_moneda = a.cod_moneda
                     and a.liquidado = 'N'
                     and a.ope_homebanking='S'
                     and trunc(a.fec_operacion)= trunc(v_fec_actual)
                     and rownum=1;
               else
                  select nro_operacion,
                         a.cod_moneda, a.cod_persona, cod_oficina, monto, cotizacion,mto_equ_local,
                         cta_referencia, cod_tra_cargo1, mto_cargo1, cod_tra_cargo2,
                         mto_cargo2, cta_ref_contra4, mto_contra4, nro_cuenta, a.cod_tip_operacion,
                         cta_ref_contra3
                    into v_nro_operacion,
                         v_cod_moneda, v_cod_persona,v_cod_oficina, v_monto,v_cotizacion,v_tot_mon_local_vta,
                         v_cta_referencia, v_cod_tra_cargo1,v_mto_cargo1 ,v_cod_tra_cargo2,
                         v_mto_cargo2,v_cta_ref_contra4,v_mto_contra4,v_cta_cambios,v_cod_tip_ope_pre,
                         v_cta_ref_contra3
                    from ba_monedas c, ba_personas b, lc_ope_pen_cambios a
                   where nro_diario=p_nro_prepactada
                     and b.cod_persona(+) = a.cod_persona
                     and c.cod_moneda = a.cod_moneda
                     and a.liquidado = 'N'
                     and a.ope_homebanking='S'
                     and a.cod_tip_operacion <> 61 -- distinto a compra debito en cuenta
                     and trunc(a.fec_operacion)= trunc(v_fec_actual)
                     and rownum=1;
               end if;
            exception
               when no_data_found then
                  v_respuesta:=-6;
            end;
               --Si el Monto del Cargo 2 se cobró es OUR , sino BEN
                if nvl(v_mto_cargo2,0)> 0  and p_tip_cargo='BEN' then
                   v_respuesta:=-33;
                elsif nvl(v_mto_cargo2,0)= 0  and p_tip_cargo='OUR' and nvl(p_exonerado,'N') = 'N' then
                    v_respuesta:=-33;
                end if;

               --Verificamos los Datos Recibidos con lo cargado en la pre-pactada
                if v_cod_moneda <> p_cod_mon_tra then
                 v_respuesta:=-7;
                elsif v_monto <> p_monto then
                 v_respuesta:=-8;
                elsif v_cod_tip_ope_pre <> v_cod_tip_ope_vta then
                  v_respuesta:=-31;
                end If;
                --03/02/2015 Si es contra Cta.Cble
                if v_cta_ref_contra4 is not null then
                    v_cod_tip_ope_cpra:= 61;
                    v_tipo:='TTE-MONEXT';
                    v_can_ope:=2;
                end if;

                  --Buscamos si tiene Prepactada 2 (Siempre Compra Debito Cta de Cliente)
                     if v_can_ope = 2 and v_respuesta = 0 then
                         v_lugar:='Obt.Ope.Prep.Compra';
                          Begin
                             select a.monto,a.cotizacion,a.nro_operacion,a.mto_equ_local,a.cta_referencia
                              into v_tot_mon_compra,v_cot_compra,v_nro_ope_compra,v_tot_mon_local,v_cta_referencia_cre
                              from ba_monedas c, ba_personas b, lc_ope_pen_cambios a
                               where a.nro_documento =v_nro_doc_cliente
                                  and b.cod_persona(+) = a.cod_persona
                                  and a.nro_diario = p_nro_prepactada
                                  and c.cod_moneda = a.cod_moneda
                                  and a.cta_referencia= p_nro_cuenta
                                  and a.cod_tip_operacion = 61 --Siempre debe ser débito en Cta de Cliente
                                  and trunc(a.fec_operacion)= trunc(v_fec_actual)
                                  and a.liquidado = 'N'
                                  and rownum=1;
                          exception
                             when no_data_found then
                                v_respuesta:=-10;
                           end;
                     End if;
               if v_can_ope =1 and v_respuesta=0 then
                 if v_cta_ref_contra3 IS NOT NULL AND v_cta_ref_contra3 <> p_nro_cuenta then
                    v_respuesta:=-10;
                 end If;
               elsif v_can_ope=2 and v_respuesta=0 then
                 --wa:02/02, se ajusta para que valide si tiene 2 cuentas
                 if v_cta_referencia_cre IS NOT NULL AND v_cta_referencia_cre <> p_nro_cuenta then
                    v_respuesta:=-10;
                 end If;
               end if;

           else
                   --****** Si no viene como prepactada *********************
                   --obtiene cta de cambios del cliente
                   v_lugar:='Obt.Cta.Cliente';
                   v_cta_cambios := lf_obt_cta_cliente;
           end if;

        end if;
        v_cod_moneda:=p_cod_mon_tra;
        v_monto:= p_monto;
       --*******Obtenemos los cargos y tasas acorde al tipo de Operación
        if v_respuesta=0 then
             begin
                   v_lugar:='Obt.Ope1. Por Tipo';
                  --Buscamos la Operación 1 (De Venta o Canje)
                  select afe_posicion, afe_limite, caja, tip_valor, cod_mod_origen,
                         cod_transaccion, cod_mad_hijo, cod_tra_cargo1, cod_tra_cargo2, cod_tra_cargo3,
                         tip_aplicacion, cod_rubro, descripcion, a.cod_tip_ope_bcp,'001',b.cod_tip_referencia,
                         a.cod_modalidad
                    into v_afe_pos_vta, v_afe_lim_vta, v_caj_vta, v_tip_val_vta, v_mod_ori_vta,
                         v_cod_tra_ope_vta, v_mad_hij_vta, v_cod_tra_cargo1, v_cod_tra_cargo2, v_cod_tra_cargo3,
                         v_tip_apl_vta, v_cod_rub_vta, v_des_ope_vta, v_ope_bcp_vta, v_cod_tip_ref_vta,v_cod_ref_cam_vta,
                         v_cod_modalidad
                    from lc_tip_ope_oficinas b, lc_tip_operaciones a
                   where b.cod_tip_operacion = a.cod_tip_operacion
                     and b.cod_moneda = v_cod_moneda --moneda de la transf
                     and b.cod_oficina = v_cod_ofi_cta --oficina de la Cta
                     and a.cod_tip_operacion = v_cod_tip_ope_vta --operación Venta/Canje
                     and nivel = 1;
                   --Si son de monedas distintas, debe haber una compra prepactada tambien
                   --16 Compra Déb Cta de Cliente /91 Canje Compra Débito en Cta de Cliente
                   if v_can_ope = 2 then
                        v_lugar:='Obt.Ope2. Por Tipo';
                        select afe_posicion, afe_limite, caja, tip_valor, cod_mod_origen,
                                cod_transaccion, cod_mad_hijo, --sin cargos
                                tip_aplicacion, cod_rubro, descripcion, a.cod_tip_ope_bcp,'001',b.cod_tip_referencia,
                                a.cod_modalidad
                           into v_afe_pos_cpra, v_afe_lim_cpra,v_caj_cpra, v_tip_val_cpra, v_mod_ori_cpra,
                                v_cod_tra_ope_cpra, v_mad_hij_cpra,
                                v_tip_apl_cpra, v_cod_rub_cpra,v_des_ope_cpra, v_ope_bcp_cpra, v_cod_tip_ref_cpra,v_cod_ref_cam_cpr,
                                v_cod_modalidad
                           from lc_tip_ope_oficinas b, lc_tip_operaciones a
                          where b.cod_tip_operacion = a.cod_tip_operacion
                            and b.cod_moneda = v_cod_moneda --moneda de la transf
                            and b.cod_oficina = v_cod_ofi_cta --oficina de la Cta
                            and a.cod_tip_operacion =v_cod_tip_ope_cpra --operación Compra (Siempre es Débito en Cuenta)
                            and nivel = 1;
                   end if;
               exception
                   when no_data_found then
                        v_respuesta:=-12;
               end;
       end if;
     --*************************************************
     if v_respuesta=0 then
         if p_nro_prepactada is null then
            --No es prepactada
            v_lugar:='Obt.Cot.Vta';
            v_cot_venta := LF_OBT_COT_HB(p_cod_mon_tra,'VEN');
            v_equ_venta := round(v_monto * v_cot_venta,v_redondeo_ml);

            if v_tipo in ('TTE-MONEXT','TTE-MONLOC') then
               v_mad_operacion := 72;
            else
              --Canje
               v_mad_operacion := 74;
            end if;

         else
            --Prepactada
            v_cot_venta := v_cotizacion;
            v_mad_operacion := nvl(v_cod_modalidad ,73);
            v_equ_venta := round(v_monto * v_cot_venta,v_redondeo_ml);
            v_tot_mon_local:=v_tot_mon_local_vta;

         end if;
      end if;
  --*************** RECUPERAMOS DATOS DEL CARGO 1****************************************
  if v_respuesta=0 then
    if v_cod_tra_cargo1 is not null then
        v_mto_cargo1:=null;
        v_des_cargo:=null;
        begin
           --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
          /* if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_ofi_cta)  then
               v_lugar:='Obt.Cargos 1.1';
               pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_equ_venta,
                                    v_cod_ofi_cta, v_cta_cambios, null, v_des_cargo,
                                    v_mto_cargo1, v_cod_tasa, v_val_tasa);
           els*/
           if v_cod_persona is not null then
              if p_cod_mon_tra <> v_cod_mon_cta then
                 v_lugar:='Obt.Cargos 1.2';
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_equ_venta,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo1, v_cod_tasa, v_val_tasa);
              else
                 --Misma moneda que la cuenta
                 v_lugar:='Obt.Cargos 1.3';
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, null,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo1, v_cod_tasa, v_val_tasa);

                 v_mto_cargo1:=v_val_tasa;

             end if;

           end if;
        exception
           when others then
                v_respuesta:=-13;
        end;
     end if;
       if v_cod_moneda= v_mon_local then
         v_mto_cargo1 := round(nvl(v_mto_cargo1,0), v_redondeo_ml);
       else
         v_mto_cargo1 := round(nvl(v_mto_cargo1,0), v_redondeo_me);
       end if;  
     --
       v_cod_tasa      :=NULL;
       v_val_tasa      :=NULL;
     if nvl(v_mto_cargo1,0) > 0 and v_respuesta=0 then
        --Verificar si tienen impuestos asociados
         v_lugar:='Obt.Imp 1 ';
           begin
            -- Tasa Generica
            pal_cam.pr_obt_impuestos(v_cod_tra_cargo1, v_mad_operacion, v_mto_cargo1,
                                 v_cod_ofi_cta, v_tra_impuesto, v_impuesto,
                                 v_cod_tasa, v_val_tasa);
            -- DYDMR-5780 05/2018 recupera tasa personalizada para el cliente
            pal_cam.pr_obt_impuestos(v_cod_tra_cargo1, v_mad_operacion, v_mto_cargo1,
                                 v_cod_ofi_cta, v_tra_impuesto, v_imp_personalizado,
                                 v_cod_tasa, v_val_tasa, null, v_cod_persona); -- DYDMR-8895 NAF 05/2018
           exception
             when others then
                v_respuesta:=-14;
           end;
        --Se guarda el impuesto del movimiento para luego utilizarlo en el desgloze del IVA si aplica.
        v_mov_impuesto := nvl(v_imp_personalizado,0);
        -- Si tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
        -- DYDMR-5780 05/2018 mejora calculo de monto en caso de tener tasa personalizada
        if v_impuesto is not null and nvl(v_impuesto,0) <> nvl(v_imp_personalizado,0) and v_respuesta=0 then
           v_mto_cargo1 :=  v_mto_cargo1 - v_impuesto;
        end if;
     end if;
 end if;
  --*************** RECUPERAMOS DATOS DEL CARGO 2****************************************
  --Si tipo es BEN no se cobra cargo II
 if p_tip_cargo= 'OUR' and v_respuesta=0 THEN

     if v_cod_tra_cargo2 is not null then
        v_mto_cargo2:=null;
        v_des_cargo:=null;
        begin
           --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
           /*
           if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_ofi_cta) then
              v_lugar:='Obt.Cargos 2.1';
              pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_mad_operacion, v_cod_moneda, v_monto, v_equ_venta,
                                    v_cod_ofi_cta, v_cta_cambios, null, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa1, v_val_tasa1);
           els*/
           if v_cod_persona is not null then
             if p_cod_mon_tra <> v_cod_mon_cta then
                v_lugar:='Obt.Cargos 2.2';
                pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_mad_operacion, v_cod_moneda,v_monto, v_equ_venta,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa1, v_val_tasa1);
              else
                 v_lugar:='Obt.Cargos 2.3';
                 pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_mad_operacion, v_cod_moneda,v_monto, null,
                                    v_cod_ofi_cta, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa1, v_val_tasa1);

                 v_mto_cargo2:=v_val_tasa1;
              end if;
           end if;
        exception
           when others then
                v_respuesta:=-15;
        end;
     end if;
     
     if v_cod_moneda= v_mon_local then
         v_mto_cargo2 := round(nvl(v_mto_cargo2,0), v_redondeo_ml);
     else
         v_mto_cargo2 := round(nvl(v_mto_cargo2,0), v_redondeo_me);
     end if; 
     
     
     v_cod_tasa1      :=NULL;
     v_val_tasa1      :=NULL;
     --
     if nvl(v_mto_cargo2,0) > 0 and v_respuesta=0  then
        --Verificar si tienen impuestos asociados
        v_lugar:='Obt.Impuesto1';
        begin
         -- Tasa Generica 
         pal_cam.pr_obt_impuestos(v_cod_tra_cargo2, v_mad_operacion, v_mto_cargo2,
                                 v_cod_ofi_cta, v_tra_impuesto1, v_impuesto1,
                                 v_cod_tasa1, v_val_tasa1);
         -- DYDMR-5780 05/2018 recupera tasa personalizada para el cliente
         pal_cam.pr_obt_impuestos(v_cod_tra_cargo2, v_mad_operacion, v_mto_cargo2,
                                 v_cod_ofi_cta, v_tra_impuesto1, v_imp_personalizado1,
                                 v_cod_tasa1, v_val_tasa1, null, v_cod_persona); -- DYDMR-8895 NAF 05/2018
        exception
          when others then
             v_respuesta:=-16;
        end;
        --Se guarda el impuesto del movimiento para luego utilizarlo en el desgloze del IVA si aplica.
        v_mov_impuesto1 := nvl(v_imp_personalizado1,0);
        -- Si tiene personalizada la tasa correspondiente al impuesto se debita la misma del cargo
        -- DYDMR-5780 05/2018 mejora calculo de monto en caso de tener tasa personalizada
        if v_impuesto1 is not null and nvl(v_impuesto1,0) <> nvl(v_imp_personalizado1,0) and v_respuesta=0 then
           v_mto_cargo2 :=  v_mto_cargo2 - v_impuesto1;
        end if;
     end if;
  end if;
If v_tipo ='TTE-MONEXT' and v_respuesta=0 then
   --***************MOVIMIENTO DE VENTA TRANSFERENCIA***************************
            IF p_nro_prepactada is  null then
               v_tot_mon_local := ROUND(NVL(v_cot_venta,0) * v_monto,v_redondeo_ml);
            end if;
             if nvl(v_mto_cargo1,0)>0 and v_respuesta=0 then
               v_mto_cargo1:= nvl(v_mto_cargo1,0);
             else
               v_mto_cargo1:= 0;
             end if;

             if nvl(v_mto_cargo2,0)>0 and v_respuesta=0 then
                 v_mto_cargo2:= nvl(v_mto_cargo2,0) ;
             else
                v_mto_cargo2:= 0;
             end if;

            p_cod_tra_padre:= 255;
            v_tot_gral:=nvl(abs(v_tot_mon_local),0)+nvl(v_mto_cargo1,0) +nvl(v_mto_cargo2,0);
            v_tot_mon_compra:= abs(v_tot_gral);
            if p_nro_prepactada is null then
               v_cot_compra := LF_OBT_COT_HB(v_cod_mon_cta,'COM');--pal_cam.FU_OBT_COT_COMPRA(v_cod_mon_cta);
            end if;
            v_redondeo_me := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,v_cod_mon_cta);
            if v_respuesta=0 then
               p_cargo:= ROUND((nvl(v_mto_cargo1,0) +nvl(v_mto_cargo2,0))/nvl(v_cot_compra,0),v_redondeo_me);
               p_importe:=ROUND(nvl(v_tot_mon_compra,0)/nvl(v_cot_compra,0),v_redondeo_me);

            end if;
elsif v_tipo ='TTE-MONLOC' and v_respuesta=0 then
  --***************OPERACION DE VENTA DE DIVISAS MON LOCAL *******************************

          IF p_nro_prepactada is  null and v_respuesta=0then
             v_tot_mon_local := ROUND(NVL(v_cot_venta,0) * v_monto,v_redondeo_ml);
          end if;
          if nvl(v_mto_cargo1,0)>0 and v_respuesta=0 then
              v_mto_cargo1:= nvl(v_mto_cargo1,0);
          else
             v_mto_cargo1:=0;
          end if;
          if p_tip_cargo= 'OUR' and v_respuesta=0 AND NVL(v_mto_cargo2,0) >0 then
                v_mto_cargo2:= nvl(v_mto_cargo2,0);
          else
            v_mto_cargo2:=0;
          end if;
          if v_respuesta=0 then
                p_cod_tra_padre:= 264;
               p_cargo:=nvl(v_mto_cargo1,0)+nvl(v_mto_cargo2,0);
               v_tot_gral:=nvl(abs(v_tot_mon_local),0)+nvl(v_mto_cargo1,0)+nvl(v_mto_cargo2,0);
               v_tot_gral:= ROUND(NVL(v_tot_gral,0),0);
               p_importe:= v_tot_gral;

          end if;

elsif v_respuesta=0 then
         --***************OPERACION DE CANJE DE DIVISAS *******************************

          v_cot_venta := pag_gen.fu_obt_cotizacion(v_cod_mon_cta,v_fec_actual);
          v_tot_gral:= nvl(v_monto,0) + nvl(v_mto_cargo1,0) +  nvl(v_mto_cargo2,0);
          v_lugar:='Obt.Par.Redondeo-CANJE';
          if nvl(v_mto_cargo1,0)>0 and v_respuesta=0 then
                v_mto_cargo1:= nvl(v_mto_cargo1,0);
          else
            v_mto_cargo1:=0;
          end if;
          if p_tip_cargo= 'OUR' and v_respuesta=0 AND NVL(v_mto_cargo2,0) >0 then
                v_mto_cargo2:= nvl(v_mto_cargo2,0);
          else
                v_mto_cargo2:= 0;
          end if;
          if v_respuesta=0 then
               p_cod_tra_padre:= 288;
               p_importe:= nvl(v_tot_gral,0);
               p_cargo:= nvl(v_mto_cargo1,0)+nvl(v_mto_cargo2,0);

          end if;

 end if;
end if;
 --************************
 p_cotizacion:=v_cot_venta;
 if v_can_ope= 2 then
    p_cot_contra:=v_cot_compra;
 else
    p_cot_contra:=null;
 end if;

 if v_respuesta=0 then
   v_lugar:='Obt.Fechas';
   --Calculo de Fecha de Operación y Fecha Valor
   v_fec_hor_corte:= to_date(to_char(v_fec_actual,'dd/mm/yyyy')||' '||v_hor_corte||':00','dd/mm/yyyy hh24:mi:ss');
   v_fec_hor_actual:= to_date(to_char(v_fec_actual,'dd/mm/yyyy')||to_char(sysdate,'hh24:mi:ss'),'dd/mm/yyyy hh24:mi:ss');
   --Sino es feriado --Es para definir fecha desde donde calcular
   if not fue_ctr_fec_feriado(sysdate,null) THEN

       --Si es sabado o domingo, no se calcula lo de la hora de Corte
       if ltrim(rtrim(upper(to_char(sysdate,'DAY')))) in ('SATURDAY','SABADO','SÁBADO','SUNDAY','DOMINGO') then
          v_lugar:='Obt.Fechas Fer';
          v_fec_operacion:= trunc(v_fec_actual);
       else
           v_lugar:='Obt.Fechas Nor';
           --Es un dia normal y se debe calcular acorde al horario de corte.
           if v_fec_hor_actual  <= v_fec_hor_corte then
              v_fec_operacion:= trunc(v_fec_actual);
           else
              v_fec_operacion:= fu_obt_fec_sig_hab(v_fec_actual,null,1);
           end if;
       end if;
   else
      --Si es feriado se toma la fecha de sistema
      v_fec_operacion:= trunc(v_fec_actual);
   end if;

   --Fecha de Valor (Se crearon Nuevas funciones porque no se toma en cuenta los feriados, no se puede utilizar el existente en pag_cal)
    if p_plazo= 0 then
      v_fec_valor:=v_fec_operacion;
    ELSIF p_plazo= 1 then
      v_fec_valor:=fu_obt_fec_sig_hab(v_fec_operacion,null,1);
    ELSIF p_plazo= 2 then
      v_fec_valor:=fu_obt_fec_sig_hab(v_fec_operacion,null,1);
      v_fec_valor:=fu_obt_fec_sig_hab(v_fec_valor,null,1);
    end if;

    p_fec_operacion:= v_fec_operacion;
    p_fec_valor:=v_fec_valor;
 end if;
 p_cod_tip_operacion := v_cod_tip_ope_vta;
 p_respuesta := v_respuesta;
EXCEPTION
  when too_many_rows then
    p_respuesta:= -17;
    RAISE_APPLICATION_ERROR( -20000, 'Mas de Una fila Recuperada: '||v_lugar);
  when others then
    p_respuesta:= v_respuesta;
    RAISE_APPLICATION_ERROR( -20000, 'Error: '||v_lugar||'- '||sqlerrm);

END;

--
PROCEDURE PR_INS_TRA_HB(
p_nro_referencia in lc_transferencias.nro_referencia%type,
p_nro_documento  in lc_transferencias.nro_operacion%type, --Nro de Doc del Mov./Nro de Ope.
p_cod_oficina in lc_transferencias.cod_oficina%type default null,
p_fec_operacion in lc_transferencias.fec_operacion%type default null,
p_cod_moneda in lc_transferencias.cod_moneda%type default null,
p_monto  in lc_transferencias.monto%type default null,
p_cod_banco  in lc_transferencias.cod_banco%type default null,
p_nom_banco  in lc_transferencias.nom_banco%type default null,
p_cod_pai_banco  in lc_transferencias.cod_pai_banco%type default null,
p_cod_ciu_banco  in lc_transferencias.cod_ciu_banco%type default null,
p_cod_aba_banco  in lc_transferencias.cod_aba_banco%type default null,
p_cod_swi_banco  in lc_transferencias.cod_swi_banco%type default null,
p_cod_per_solicitante  in lc_transferencias.cod_per_solicitante%type default null,
p_nom_solicitante  in lc_transferencias.nom_solicitante%type default null,
p_dir_solicitante  in lc_transferencias.dir_solicitante%type default null,
p_tel_solicitante  in lc_transferencias.tel_solicitante%type default null,
p_cod_pai_solicitante  in lc_transferencias.cod_pai_solicitante%type default null,
p_cod_ciu_solicitante  in lc_transferencias.cod_ciu_solicitante %type default null,
p_cod_per_beneficiario  in lc_transferencias.cod_per_beneficiario%type default null,
p_nom_beneficiario  in lc_transferencias.nom_beneficiario%type default null,
p_dir_beneficiario  in lc_transferencias.dir_beneficiario%type default null,
p_tel_beneficiario  in lc_transferencias.tel_beneficiario%type default null,
p_cod_pai_beneficiario  in lc_transferencias.cod_pai_beneficiario%type default null,
p_cod_ciu_beneficiario  in lc_transferencias.cod_ciu_beneficiario%type default null,
p_nro_cta_referencia  in lc_transferencias.nro_cta_referencia%type default null,
p_fec_recepcion  in lc_transferencias.fec_recepcion %type default null,
p_cod_rubro  in lc_transferencias.cod_rubro%type default null,
p_plazo  in lc_transferencias.plazo %type default null,
p_observacion  in lc_transferencias.observacion%type default null,
p_cod_uid_banco  in lc_transferencias.cod_uid_banco%type default null,
p_tip_cargo  in lc_transferencias.tip_cargo%type default null,
p_cod_bco_cor_contra  in lc_transferencias.cod_bco_cor_contra%type default null,
--Para intermediario
p_nom_bco_cor_contra  in lc_transferencias.nom_bco_cor_contra%type default null,
p_cod_swi_bco_contra  in lc_transferencias.cod_swi_bco_contra%type default null,
p_cod_pai_bco_contra  in lc_transferencias.cod_pai_bco_contra%type default null,
p_cod_ciu_bco_contra  in lc_transferencias.cod_ciu_bco_contra%type default null,
--
p_nom_ciu_beneficiario  in lc_transferencias.nom_ciu_beneficiario%type default null,
p_nom_ciu_solicitante  in lc_transferencias.nom_ciu_solicitante%type default null,
p_nro_doc_beneficiario  in lc_transferencias.nro_doc_beneficiario%type default null,
p_fec_valor  in lc_transferencias.fec_valor%type default null,
p_tip_fondo in lc_transferencias.tip_fondo%type default null,
p_tip_motivo in lc_transferencias.tip_fondo%type default null,
p_tip_financiacion in lc_transferencias.tip_fondo%type default null,
p_cod_tip_referencia lc_transferencias.cod_tip_referencia%type default null,
p_referencia  in lc_transferencias.referencia%type default null,
p_mto_cargo in lc_transferencias.mto_cargo%type default null,
p_nro_documento2 in lc_transferencias.Nro_Operacion2%type default null,
--DNA
p_nro_ord_pag_dna in lc_transferencias.nro_ord_pag_dna%type default null,
p_nro_cta_debito  in lc_transferencias.nro_cta_debito%type default null,
p_respuesta out number
) is

v_bco_corresponsal varchar2(30);
v_respuesta number:=0;
v_cod_modulo lc_transferencias.cod_modulo%type default 7;--Siempre es Cambios
v_cod_modalidad lc_transferencias.cod_modalidad%type default 72; --Siempre es Vta Transferencia
v_cod_tip_referencia lc_transferencias.cod_tip_referencia%type default null;
v_nro_referencia lc_transferencias.nro_referencia%type;
v_nro_operacion lc_transferencias.nro_operacion%type;
v_nro_ref_externa lc_transferencias.nro_ref_externa%type;
v_saldo lc_transferencias.saldo%type:=0; --Se asigna cero en el CORE cuando es TTE.
v_cod_msj_swift lc_transferencias.cod_msj_swift%type:=103; --Cliente a Cliente siempre
v_tip_mensaje lc_transferencias.tip_mensaje%type:='CRED'; --Siempre CRED
v_cod_banco ge_bancos.cod_banco%type;
v_cantidad number(3);
v_cod_pai_beneficiario lc_transferencias.cod_pai_beneficiario%type;
v_cod_ciu_beneficiario lc_transferencias.cod_ciu_beneficiario%type;
v_cod_per_banco ge_bancos.cod_persona%type;
v_cod_ciu_banco ba_ciudades.cod_ciudad%type;
v_ciu_banco ba_ciudades.descripcion%type;
v_cod_pai_banco ba_paises.cod_pais%type;
v_pai_banco ba_paises.descripcion%type;
v_observacion lc_transferencias.observacion%type;
v_existe number:=0;
v_cod_banco_int lc_transferencias.cod_bco_cor_contra%type;
v_autorizado varchar2(1):='N';
/* Listado de respuestas posibles
0   'Ok'
-1  'TTE habilitado para Euros y Dólares'
-2  'Monto de Operación debe ser mayor a Cero'
-3  'El tipo de Cargo debe ser OUR o BEN'
-4  'Plazo debe ser 0(0 horas)/1(24 horas)/2(48 horas)'
-5  'Obtener Banco Corresponsal'
-6  'Mas de una fila Recuperada'
-7  'Insertar Tranferencia'
-8  'Banco Intermediario Inexistente'
-9  'Banco del Beneficiario Inexistente en ITGF'
-10 'Pais de Banco del Beneficiario no corresponde'
-11 'Ciudad de Banco del Beneficiario no corresponde'
-12 'Pais de Banco del Intermediario no corresponde'
-13 'Ciudad de Banco del Intermediario no corresponde'
*/

BEGIN
      -- para NLS B.D.
       PRE_CAM_FOR_NUMERICO('.,');

      if p_cod_moneda not in ('USD','EUR') then
        v_respuesta:=-1;
      end if;
      if nvl(p_monto,0)<=0  then
        v_respuesta:=-2;
      end if;
      if p_tip_cargo not in ('OUR','BEN') then
         v_respuesta:=-3 ;
      end if;
        --Validamos Plazo
       if p_plazo not in (0,1,2) then
         v_respuesta:=-4;
       end if;
       --Si recibimos cargamos
       --Sino se recibe se envia '00'
       if p_cod_tip_referencia is not null then
         v_cod_tip_referencia:=p_cod_tip_referencia;
       else
          v_cod_tip_referencia:='00';
       end if;

        --Obtenemos los datos de nro_referencia/Nro_operacion/nro_ref_externa
         v_nro_referencia:= p_nro_referencia;
         v_nro_operacion := p_nro_documento;--fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, p_cod_moneda, p_cod_oficina)+1;
         v_nro_ref_externa := v_cod_tip_referencia||'/'||v_nro_referencia;
        --Obtenemos el Código del Bco Corresponsal acorde a la Moneda
       if v_respuesta=0 then
          begin
            select r.abreviatura
              into v_bco_corresponsal
              from ba_cod_referencias r
             where r.dominio = 'TRA_CORRESPONSAL_'||UPPER(p_cod_moneda)
              and p_monto between to_number(replace(r.val_minimo,',','.')) and to_number(replace(r.val_maximo,',','.'));
          exception
            when others then
              v_respuesta:=-5;
          end;
        end if;

        --Si recibimos cod_banco igual a null, asignamos 999
        --similar al CORE
       if p_cod_banco is null and v_respuesta=0 then
            v_cod_banco:=999;
       elsif v_respuesta=0 then
            --Validamos que exista
          v_cantidad:=0;
          begin
            SELECT count(*),a.cod_persona
               into v_cantidad,v_cod_per_banco
                 FROM GE_BANCOS a
                  where a.estado ='A'
                   AND COD_BANCO <> 999
                   and a.cod_banco=p_cod_banco
                   group by a.cod_persona;
          exception
            when no_data_found then
              v_cantidad:=0;
            when others then
              v_cantidad:=0;
          end;
          if nvl(v_cantidad,0)=0 and v_respuesta=0 then
               v_respuesta:=-9;
          end if;
          IF v_respuesta=0 then
             v_cod_banco:=p_cod_banco;
          end if;
          --Obtenemos Pais y Ciudad del Banco y validamos con lo ingresado.
          pre_obt_ciu_pais(v_cod_per_banco, v_cod_pai_banco, v_pai_banco, v_cod_ciu_banco, v_ciu_banco);
          if nvl(v_cod_pai_banco,-99) <> nvl(p_cod_pai_banco,-99) then
            v_respuesta:=-10;
          end if;
          if nvl(v_cod_ciu_banco,-99) <> nvl(p_cod_ciu_banco,-99) then
            v_respuesta:=-11;
          end if;

      end if;
       --Verificamos pais y ciudad del beneficiario

       if v_cod_banco is not null and v_respuesta=0 then
         if p_cod_pai_beneficiario is null then
            v_cod_pai_beneficiario:=p_cod_pai_banco;
         else
            v_cod_pai_beneficiario:=p_cod_pai_beneficiario;
         end if;

         if p_cod_ciu_beneficiario is null then
            --Se asigna ambos, porque se busca por pais ciudad en Generación de Swift
            v_cod_pai_beneficiario:=p_cod_pai_banco;
            v_cod_ciu_beneficiario:=p_cod_ciu_banco;
         else
            v_cod_ciu_beneficiario:=p_cod_ciu_beneficiario;
         end if;

       end if;


       --Verificamos el Banco Intermediario(Opcional) , si recibimos null asignamos 999
       if p_cod_bco_cor_contra is null then
         v_cod_banco_int:=999;
       else
         v_cod_banco_int:=p_cod_bco_cor_contra;
       end if;
       if v_cod_banco_int is not null and v_respuesta=0 then
          v_cantidad:=0;
          begin
            SELECT count(*)
               into v_cantidad
                 FROM GE_BANCOS a
                  where a.estado ='A'
                   and a.ubicacion = 'E'
                   and a.cod_banco=v_cod_banco_int;
          exception
            when no_data_found then
              v_cantidad:=0;
            when others then
              v_cantidad:=0;
          end;
          if nvl(v_cantidad,0)=0 and v_respuesta=0 then
               v_respuesta:=-8;
          end if;
          --Validamos el Pais del Banco Intermediario

          if p_cod_pai_bco_contra is not null
             and v_cod_banco_int= 999 then

            v_existe:=0;
            begin
              select count(*)
                 into v_existe
                  from ba_paises a
                   where a.cod_pais=p_cod_pai_bco_contra;
            exception
              when no_data_found then
                v_existe:=0;
              when others then
                v_existe:=0;
            end;
             if  v_existe =0 then
                v_respuesta:=-12;
             end if;

          end if;
           --Validamos la ciudad del Banco Intermediario
          if p_cod_ciu_bco_contra is not null
            and v_cod_banco_int= 999 then

            v_existe:=0;
            begin
              select count(*)
                 into v_existe
                  from ba_ciudades a
                   where a.cod_ciudad=p_cod_ciu_bco_contra;
            exception
              when no_data_found then
                v_existe:=0;
              when others then
                v_existe:=0;
            end;
             if  v_existe =0 then
                v_respuesta:=-13;
             end if;

          end if;




       end if;
       --Concatenamos
       --wa:02/01/2015, no se concatena, se guarda lo recibido
       --v_observacion:=trim(p_observacion)||' / '||trim(p_referencia);
       v_observacion:=trim(p_observacion);
       --wa: Para Normativo 30/01/2015
       if p_tip_motivo is not null then
          v_autorizado:= pas_tra.fu_obt_mot_autoriza(p_tip_motivo);
       else
         v_autorizado:= 'N';
       end if;


  if v_respuesta= 0 then
      -- inserto el registro en transferencias
      --El banco siempre se grabará 999 por codifi. de generación de Swift
      --Cuando se arregle la generación de mensajería se ingresará el código de Banco
      insert into lc_transferencias
             (nro_referencia, cod_tip_referencia, cod_modulo, cod_modalidad, cod_oficina, fec_operacion,
              nro_operacion, cod_moneda, monto, saldo, cod_banco, nom_banco, cod_pai_banco, cod_ciu_banco,
              cod_aba_banco, cod_swi_banco, cod_bco_corresponsal, cod_per_solicitante, nom_solicitante,
              dir_solicitante, tel_solicitante, cod_pai_solicitante, cod_ciu_solicitante, cod_per_beneficiario,
              nom_beneficiario, dir_beneficiario, tel_beneficiario, cod_pai_beneficiario, cod_ciu_beneficiario,
              nro_cta_referencia, fec_recepcion, cod_rubro, plazo, observacion,
              cod_uid_banco, nro_ref_externa, tip_mensaje, tip_cargo, cod_bco_cor_contra,
              nom_ciu_beneficiario,
              nom_ciu_solicitante,estado,nro_doc_beneficiario, fec_valor,cod_msj_swift,
              tip_fondo,tip_motivo,tip_financiacion,referencia, mto_cargo, nro_operacion2,
              nom_bco_cor_contra,cod_swi_bco_contra,cod_pai_bco_contra,cod_ciu_bco_contra, autorizado,
              nro_ord_pag_dna,nro_cta_debito )
       values
             (v_nro_referencia, v_cod_tip_referencia, v_cod_modulo,
              v_cod_modalidad, p_cod_oficina, p_fec_operacion,
              v_nro_operacion, p_cod_moneda, p_monto, v_saldo,/*999*/ v_cod_banco,
              p_nom_banco, p_cod_pai_banco, p_cod_ciu_banco,
              p_cod_aba_banco, p_cod_swi_banco, v_bco_corresponsal,p_cod_per_solicitante, p_nom_solicitante,
              p_dir_solicitante, p_tel_solicitante, p_cod_pai_solicitante,p_cod_ciu_solicitante, p_cod_per_beneficiario,
              p_nom_beneficiario, p_dir_beneficiario, p_tel_beneficiario, v_cod_pai_beneficiario, v_cod_ciu_beneficiario,
              p_nro_cta_referencia, p_fec_recepcion, p_cod_rubro, p_plazo, v_observacion,
              p_cod_uid_banco, v_nro_ref_externa, v_tip_mensaje, p_tip_cargo,p_cod_bco_cor_contra,
              p_nom_ciu_beneficiario,
              p_nom_ciu_solicitante, 'C', p_nro_doc_beneficiario, p_fec_valor,v_cod_msj_swift,
              p_tip_fondo,p_tip_motivo,p_tip_financiacion,p_referencia, p_mto_cargo,p_nro_documento2,
              p_nom_bco_cor_contra,p_cod_swi_bco_contra,p_cod_pai_bco_contra,p_cod_ciu_bco_contra,v_autorizado,
              p_nro_ord_pag_dna, p_nro_cta_debito);
  end if;

    p_respuesta:=v_respuesta;
EXCEPTION
  when too_many_rows then
    p_respuesta:=-6;
    RAISE_APPLICATION_ERROR( -20000, 'Mas de Una fila Recuperada: ');
  when others then
    p_respuesta:=-7;
    RAISE_APPLICATION_ERROR( -20000, 'Error: '||sqlerrm);

END;
FUNCTION FU_OBT_FEC_HABIL
 (P_FECHA IN DATE
 ,P_FACTOR IN NUMBER
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 )
 RETURN DATE
 IS

/* Recupera el parametro que indica si se trabaja sábado o domingo. */
FUNCTION LF_OBT_PAR_SABDOM
 (P_PARAMETRO IN GE_PARAMETROS.PARAMETRO%TYPE
 )
 RETURN VARCHAR2;
v_fec_habil  date;

/* Recupera el parametro que indica si se trabaja sábado o domingo. */
FUNCTION LF_OBT_PAR_SABDOM
 (P_PARAMETRO IN GE_PARAMETROS.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS
v_valor   ge_par_dinamicos.val_parametro%type;
BEGIN
   select d.val_parametro
   into v_valor
   from ge_parametros g, ge_par_dinamicos d
   where g.parametro = p_parametro
   and g.parametro = d.parametro;
   v_valor := ltrim(rtrim(v_valor));

   return v_valor;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Param. '||p_parametro||' no existe');
   when too_many_rows then
      raise_application_error(-20000,
      'Recuperar '||p_parametro||' '||sqlerrm);
END;
BEGIN
   v_fec_habil := p_fecha;
   loop
         --- Verificar si es sabado o domingo
         if (lf_obt_par_sabdom('IND_SABADO')  = 'N' and ltrim(rtrim(upper(to_char(v_fec_habil,'DAY')))) in ('SATURDAY','SABADO','SÁBADO'))
         or (lf_obt_par_sabdom('IND_DOMINGO') = 'N' and ltrim(rtrim(upper(to_char(v_fec_habil,'DAY')))) in ('SUNDAY','DOMINGO')) then
            null;
         else
            exit;  --- Salir si la fecha es HABIL
         end if;

      v_fec_habil := v_fec_habil + p_factor;
   end loop;
   return v_fec_habil;

   exception
      when others then
      raise_application_error(-20000, sqlerrm || ' ' ||
      'Obt. fecha hábil: '||TO_CHAR(p_fecha,'DD/MM/YYYY') || ' fallo');

END;
/* Obtiene la Siguiente fecha habil */
FUNCTION FU_OBT_FEC_SIG_HAB
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_DIAS IN NUMBER default 1
 )
 RETURN DATE
 IS

V_FEC_PROXIMA DATE;
BEGIN
--Obtiene la siguiente fecha hábil
   v_fec_proxima := fu_obt_fec_habil(p_fecha+p_dias,1, p_cod_oficina);
   return v_fec_proxima;
exception
   when others then
      raise_application_error(-20000,
      'Obt Sig.fecha habil: '||TO_CHAR(p_fecha,'DD/MM/YYYY') || ' fallo');
END;

--Validación de Transferencias Duplicadas Enviadas en el útimo mes
FUNCTION FU_VAL_TRA_DUP
(
p_cod_mon_tra       in varchar2 default null, --Moneda Transferencia
p_monto             in number default null, --Monto de la Transferencia
p_cod_per_solicitante in number default null, --Cod.Persona Solicitante
p_nro_cta_referencia in varchar2 default null --Nro de Cuenta de Beneficiario
)
return number
IS
--Valores de Retorno posibles
--0 no hay duplicadas
--1 si hay duplacadas
v_existe number:=0;
v_fec_desde date;
BEGIN
 v_fec_desde:= trunc(sysdate) -30; --Los ultimos 30 días
--Buscamos si existe duplicado
 begin
  select count(*)
   into v_existe
    from lc_transferencias a
     where a.monto=p_monto --Monto
      and a.cod_moneda=p_cod_mon_tra  --Moneda
      and a.cod_per_solicitante=p_cod_per_solicitante --Cod.per solicitante
      and a.nro_cta_referencia= p_nro_cta_referencia --Nro Cta Beneficiario
      and a.fec_operacion between trunc(v_fec_desde) and trunc(sysdate)
      and a.cod_modalidad=72; --TTE Enviadas
 exception
   when no_data_found then
     v_existe:=0;
   when too_many_rows then
     v_existe:=1;
   when others then
     v_existe:=0;
 end;
  v_existe:= nvl(v_existe,0);
  if nvl(v_existe,0)>0 then
    v_existe:=1;
  else
    v_existe:=0;
  end if;


 return v_existe;
exception
   when others then
      raise_application_error(-20000,'Obt.Tra.Dup.');
END;


--Obtenemos el monto del contrato de cambios
FUNCTION FU_OBT_MTO_CONTRATO
(
p_nro_prepactada    in number,
p_cod_moneda        out ba_monedas.cod_moneda%type) --Nro de Operación Pre-pactada
return number
IS
v_importe number(18,2);
v_fec_actual        date := pag_cal.fu_obt_fec_actual(9);
--Valores de Retorno posibles
--Monto de la prepactada
-- -1 No se recibió parámetro
-- -2 No se encuentra la prepactada

BEGIN
  p_cod_moneda:=null;
  if p_nro_prepactada is null then
     v_importe:=-1;     
  else
    Begin
     select  monto, a.cod_moneda
      into v_importe, p_cod_moneda
       from ba_monedas c, ba_personas b, lc_ope_pendientes a
       where --nro_operacion = p_nro_prepactada
        nro_diario=p_nro_prepactada
        and b.cod_persona(+) = a.cod_persona
        and c.cod_moneda = a.cod_moneda
        and a.liquidado = 'N'
        and a.ope_homebanking='S'
        and trunc(a.fec_operacion)= trunc(v_fec_actual)
        and rownum=1;
       exception
            when no_data_found then
               v_importe:=-2;
       end;
end if;

return v_importe;

exception
   when others then
      raise_application_error(-20000,'Obt.Contrato');
END;

--Consulta de Boletas de Ordenes de Pago DNA
PROCEDURE PR_CON_BOL_PAG_DNA
( p_nro_ord_pago        in varchar2 default null,   --Nro Orden de Pago DNA
  p_cod_mon_tte         in varchar2 default null,  --Moneda Origen TTE
  p_mto_tte             in number default null,    --Monto de Origen TTE
  p_nro_documento       in varchar2 default null,  --Nro de Documento
  p_tip_documento       in varchar2 default null,  --Tipo de Documento
  --respuesta DNA
  p_cod_moneda          out varchar2, --Codigo de Moneda IT
  p_fecha               out date,     --Fecha Creacion
  p_fec_vto             out date,     --Fecha Vencimiento
  p_tot_pagar           out number,   --Total a Pagar
  p_cotizacion          out number,   --Cotizacion DNA
  -- Respuesta de Servicio
  p_respuesta           out number,   --Respuesta 0 sino hubo errores, sino error
  p_msj_error         out varchar2    --Mensaje de Error si Hubo
)IS
/*Procedimiento para registrar consultas de Boletas de Pago realizadas a DNA*/
v_lugar           varchar2(3000);
v_cod_usuario     ge_movimientos.cod_usuario%type:=USER;
v_fec_actual      date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
v_hora            varchar2(10);
v_fecha           date;     --Fecha
v_error           varchar2(3000);
v_tip_doc_dna     varchar2(10);
--JSON
v_parametros      VARCHAR2(3000);
v_respuesta       VARCHAR2(10):=0;
c_ws_metodo       CONSTANT VARCHAR2(50) := fug_obt_pardinamico('URL_CON_BOL_INT_DNA');--'/serv/bcp/ticket_consult';
v_hab_con_dna     VARCHAR2(50) := nvl(fug_obt_pardinamico('HAB_CON_DNA'),'S');
v_url             VARCHAR2(100) := '';
v_ws_respuesta    paw_json.JSONStructObj;
v_errorPost       VARCHAR2(1);
v_resPost         TYP_POSTRESPUESTA;
v_resultado       varchar2(4500);
v_cod_retorno     varchar2(4500);
v_des_retorno     varchar2(4500);
v_nro_org_pag_rec varchar2(50); --Nro Orden de Pago DNA recibido
v_cod_moneda      varchar2(50); --Codigo de Moneda IT
v_fec_ini         varchar2(50); --Fecha Inicio
v_fec_vto         varchar2(50); --Fecha Vencimiento
v_fec_vto_it      date;         --Fceha de Vencimiento en formato IT
v_tot_pagar       varchar2(50); --Total a Pagar
v_cotizacion      varchar2(50); --Cotizacion DNA
v_cod_mon_it      varchar2(50); --Codigo de moneda de IT
--v_nro_doc_bbva    varchar2(50):='80022955-0';--RUC DEL BANCO
v_canal           varchar2(30);
v_nro_documento   varchar2(30);
v_guion           number(10);
v_dig_verificador varchar2(10);
v_parte1           varchar2(30);
v_parte2           varchar2(30);
status_code        varchar2(30000);
--
v_cod_persona      ba_personas.cod_persona%type;
v_nro_doc_cli      varchar2(100);
v_tip_doc_cli      varchar2(20);

BEGIN
   /********** Inicio de Proceso Principal *********/
   BEGIN PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1; END;
if UPPER(v_hab_con_dna) ='S' THEN   
   v_error:= null;
   v_respuesta:= 0;
   -- NLS B.D.
   PRE_CAM_FOR_NUMERICO('.,');
   v_lugar:= 'Validando Orden de Pago';
   --Validamos Orden de Pago
   if p_nro_ord_pago is null then
      v_respuesta:=20;
      v_error:= 'CAMPO ID ORDEN DE PAGO NULO';
   elsif length(trim(p_nro_ord_pago)) <> 16 THEN--16 then
      v_respuesta:=21;
      v_error:= 'CAMPO ID ORDEN DE PAGO DEBE TENER LONGITUD 16';
   end if;

    v_lugar:= 'Buscando Canal';
    if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
       v_canal:= 'HBANK';
    else
       v_canal:='CORE';
    end if;
    --Buscamos el codigo de Persona del cliente
     v_cod_persona:= null;
     begin
         select a.cod_persona
          into v_cod_persona
           from ba_personas a
            where a.nro_documento= p_nro_documento
               and a.cod_tip_documento= p_tip_documento;
       exception
         when no_data_found then
           v_cod_persona:= null;
         when others then
           v_cod_persona:= null;
       end;
    --*********02/06/2019 Ajuste para clientes con otro tip doc dna
    v_nro_doc_cli:= null;
    v_tip_doc_cli:= null;
     begin
         select a.nro_documento,a.cod_tip_documento
          into v_nro_doc_cli, v_tip_doc_cli
           from ba_per_documentos a
            where a.cod_persona= v_cod_persona
              and nvl(a.dna,'N')='S'
                and rownum=1;
       exception
         when no_data_found then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
         when others then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
       end;  
       --Sino encontramos en la tabla se asume lo recibido
       if v_nro_doc_cli is null and  v_tip_doc_cli is null then
          v_nro_doc_cli:=p_nro_documento;
          v_tip_doc_cli:= p_tip_documento;
       end if;
    --***********FIN DE AJUSTE
    v_lugar:= 'Buscando Tipo de Documento';
       begin
         select upper(a.abreviatura)
          into v_tip_doc_dna
           from ba_tip_documentos a
            where a.cod_tip_documento= v_tip_doc_cli/*p_tip_documento*/;
       exception
         when no_data_found then
           v_tip_doc_dna:= null;
         when others then
           v_tip_doc_dna:= null;
       end;
     --Se envian tipo de documento RUC (Con digito verificador) /CI /OTR 
     if v_tip_doc_dna <> 'RUC' THEN
        if v_tip_doc_dna <> 'CI' then
           v_tip_doc_dna:='OTR';
        end if;
        --Se ajusta para enviar RUC si es contribuyente
        IF v_tip_doc_dna = 'CI' THEN
          --Solo se ajusta si es contribuyente, sino se envia tal cual
          IF nvl(FUE_OBT_PER_TIP_IVA(v_cod_persona),'NC')= 'CO' then
             v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*p_nro_documento*/);
             v_nro_documento:= v_nro_doc_cli/*p_nro_documento*/||v_dig_verificador;   
             v_tip_doc_dna :='RUC';
          else
             v_nro_documento:=v_nro_doc_cli/*p_nro_documento*/;
          end if;
        ELSE
          --Para otros documentos se envia tal cual
          v_nro_documento:=v_nro_doc_cli/*p_nro_documento*/;        
        END IF;
     elsif  v_tip_doc_dna='RUC' THEN
          v_guion:= instr(v_nro_doc_cli/*p_nro_documento*/,'-');
          if v_guion = 0 then
            --No tiene guion, agregamos el digito verificador al final
            v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*p_nro_documento*/);
            v_nro_documento:= v_nro_doc_cli/*p_nro_documento*/||v_dig_verificador;
          else
            --Ya se recibe con guion
            v_parte1:=  substr(v_nro_doc_cli/*p_nro_documento*/,1,v_guion-1);
            v_parte2:=  substr(v_nro_doc_cli/*p_nro_documento*/,v_guion+1,1);
            v_nro_documento:= v_parte1||v_parte2;
          end if;
     END IF;
 
 if  to_number(v_respuesta)= 0 then
      v_lugar:= 'Cargando URL JSON';
      v_url := g_dna_webservice || c_ws_metodo;
      v_lugar:= 'Cargando Parametros';
      v_parametros := utl_lms.format_message('accessToken=%s&idOrdenPago=%s&tipoDocumento=%s&nroDocumento=%s',g_api_gateway, utl_url.escape(p_nro_ord_pago),utl_url.escape(v_tip_doc_dna), utl_url.escape(v_nro_documento));
      v_lugar:= 'Enviando env Pos';
      v_resPost := fue_env_post(p_parametros => v_parametros, p_url => v_url);
   IF (v_resPost.error = 'N') THEN
      v_lugar:= 'Seteando resp. de Pos';
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      v_cod_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'codigoRetorno');
      v_des_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'descripcionRetorno');
      v_nro_org_pag_rec:= paw_json.getAttrValue(v_ws_respuesta, 'idOrdenPago');
      v_cod_moneda:=paw_json.getAttrValue(v_ws_respuesta, 'moneda');
      v_fec_ini:=paw_json.getAttrValue(v_ws_respuesta, 'fecha');
      v_fec_vto:=paw_json.getAttrValue(v_ws_respuesta, 'vencimiento');
      v_tot_pagar:=paw_json.getAttrValue(v_ws_respuesta, 'totalPagar');
      v_cotizacion:=paw_json.getAttrValue(v_ws_respuesta, 'cotizacion');

      v_resultado:= v_resPost.respuesta;
      v_respuesta:= 0;

      if v_des_retorno is null and v_cod_retorno is null  then
          p_cod_moneda:=null;
          p_fecha:=null;
          p_fec_vto:=null;
          p_tot_pagar:=null;
          p_cotizacion:=null;
          p_respuesta:=null;
         if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
            v_error:= 'ERROR INTERNO...';
            v_respuesta:= 3;
         else
            --Se mejora mensaje de Salida para ITGF
            v_error:= 'Servicio de Consulta a DNA con inconvenientes!! Intente mas tarde!!';
            v_respuesta:= 3;
         end if; 
      end if;

      IF TO_NUMBER(nvl(v_cod_retorno,0))<> 0 then
          p_cod_moneda:=null;
          p_fecha:=null;
          p_fec_vto:=null;
          p_tot_pagar:=null;
          p_cotizacion:=null;
          p_respuesta:=null;
          v_error:= v_des_retorno;
          v_respuesta:= v_cod_retorno;
      end if;

      if to_number(v_respuesta) = 0 then
          v_lugar:= 'Buscando moneda de ITGF';
          --Buscamos codigo de moneda ITGF
           begin
             select a.cod_moneda
              into v_cod_mon_it
               from ba_monedas a
                where UPPER(a.cod_mon_iso)= upper(v_cod_moneda);
           exception
             when no_data_found then
               v_cod_mon_it:= null;
             when others then
               v_cod_mon_it:= null;
           end;
          v_lugar:= 'Validando Fecha de Vencimiento';
          v_fec_vto_it:= to_date((substr(v_fec_vto,7,2)||'/'||substr(v_fec_vto,5,2) ||'/'||substr(v_fec_vto,1,4)),'dd/mm/yyyy');
          if trunc(v_fec_vto_it) < trunc(v_fec_actual) then
             v_respuesta:= -1;
             v_error:='La Fecha de vencimiento de la Operacion en DNA es menor a Hoy';
          end if;

          if p_cod_mon_tte is not null then
            if v_cod_mon_it <> p_cod_mon_tte then
               v_respuesta:= -4;
               v_error:='La Moneda ingresada: '||p_cod_mon_tte|| ' difiere de la registrada en DNA: '|| v_cod_mon_it;
            end if;
          end if;

          v_lugar:= 'Validando Monto DNA/BBVA';
          if nvl(p_mto_tte,0) <> 0 then
            if NVL(p_mto_tte,0) <> NVL(v_tot_pagar,0) then
               v_respuesta:= -5;
               v_error:='El monto de la TTE: '||p_mto_tte|| ' difiere de lo registrado en DNA: '|| v_tot_pagar;
            end if;
          end if;

      end if;
      if v_respuesta= 0 then
          --Seteamos output
          v_lugar:= 'Cargando respuestas';
          p_cod_moneda:=v_cod_mon_it;
          p_fecha:= substr(v_fec_ini,7,2)||'/'||substr(v_fec_ini,5,2) ||'/'||substr(v_fec_ini,1,4);
          p_fec_vto:=substr(v_fec_vto,7,2)||'/'||substr(v_fec_vto,5,2) ||'/'||substr(v_fec_vto,1,4);
          p_tot_pagar:=v_tot_pagar;
          p_cotizacion:=v_cotizacion;
          v_error:= null;
          v_respuesta:= 0;
      end if;
   ELSE
      --Seteamos output
      v_lugar:= 'Cargando respuesta por Error';
      p_cod_moneda:=null;
      p_fecha:=null;
      p_fec_vto:=null;
      p_tot_pagar:=null;
      p_cotizacion:=null;
      p_respuesta:=null;
      if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
            v_error:= 'ERROR INTERNO.';
            v_respuesta:= 3;
      else
            --Se mejora mensaje de Salida para ITGF
            v_error:= 'Servicio de Consulta a DNA con inconvenientes!! Intente mas tarde!!';
            v_respuesta:= 3;
      end if; 
    
    END IF;

 end if;

  if  to_number(v_respuesta)= 0 then
      v_lugar:= 'Insertando en tabla de consulta de Boletas de Pago';
      v_hora:= to_char(sysdate,'hh24:mi:ss');
      INSERT INTO LC_CON_BOL_OPE_DNA(cod_ord_ope,
                              fecha_env,
                              hora_env,
                              tip_documento,
                              nro_documento,
                              cod_moneda,
                              fec_creacion,
                              fec_vencimiento,
                              tot_pago,
                              cotizacion,
                              fecha_res,
                              hora_res,
                              estado ,
                              mensaje ,
                              respuesta,
                              observacion,
                              tip_consulta)
                        values(p_nro_ord_pago,
                              v_fec_actual,
                              v_hora,
                              v_tip_doc_dna,
                              v_nro_documento,
                              p_cod_moneda,
                              p_fecha,
                              p_fec_vto,
                              p_tot_pagar,
                              p_cotizacion,
                              sysdate,
                              to_char(sysdate,'hh24:mi:ss'),
                              null,
                              v_parametros,
                              v_resultado,
                              null,
                              'BOL');
              --se comitea si es en el core(Si es del HB no se comitea)
              if v_canal = 'CORE' then
                 commit;
              end if;

   end if;
   --Salida
   p_respuesta:= to_number(v_respuesta);
   p_msj_error:= v_error;
else
   p_respuesta:= 0;
   p_msj_error:= null;
end if;

EXCEPTION
  when others then
    p_respuesta:= v_respuesta;
    p_msj_error:= 'C.B.E.: '||p_nro_ord_pago||'-'||v_lugar||'- '||sqlerrm;
END;

-- Consulta de Operaciones DNA
PROCEDURE PR_CON_OPE_DNA
( p_nro_ord_pago        in varchar2 default null,  --Nro Orden de Pago DNA
  p_cod_mon_tte         in varchar2 default null,  --Moneda Origen TTE
  p_mto_tte             in number default null,    --Monto de Origen TTE
  p_nro_documento       in varchar2 default null,  --Nro de Documento
  p_tip_documento       in varchar2 default null,  --Tipo de Documento

  --Respuesta DNA
  p_tip_doc_pagador     out varchar2,  --Tipo de Documento IT
  p_nro_doc_pagador     out varchar2,  --Nro de Documento Pagador
  p_razon_social        out varchar2,  --Razon Social
  p_estado              out varchar2,  --Estado de la Operacion(ENC(En curso)/ANU(anulado)/VEN(vencimiento))
  p_fec_creacion        out date,      --Fecha de Creacion
  p_fec_vencimiento     out date,      --Fecha Vencimiento
  p_cod_mon_origen      out varchar2,  --Moneda Origen (IT)
  p_mto_origen          out number,    --Monto de Origen
  p_sal_origen          out number,    --Saldo de Origen
  -- Respuesta de Servicio
  p_respuesta           out number,    --Respuesta 0 sino hubo errores, sino error
  p_msj_error           out varchar2   --Mensaje de Error si Hubo
)IS
/*Procedimiento para registrar consultas de operaciones realizadas a DNA
*/
v_lugar             varchar2(4000);
v_cod_usuario       ge_movimientos.cod_usuario%type:=USER;
v_fec_actual        date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
v_hora              varchar2(10);
v_fecha             date;
v_error             varchar2(3000);
--JSON
v_parametros        VARCHAR2(3000);
v_respuesta         VARCHAR2(10):=0;
c_ws_metodo         CONSTANT VARCHAR2(50) := fug_obt_pardinamico('URL_CON_OPE_INT_DNA');
v_url               VARCHAR2(100) := '';
v_ws_respuesta      paw_json.JSONStructObj;
v_errorPost         VARCHAR2(1);
v_resPost           TYP_POSTRESPUESTA;
v_resultado         varchar2(4500);
v_cod_retorno       varchar2(4500);
v_des_retorno       varchar2(4500);
v_nro_org_pag_rec   varchar2(50);  --Nro Orden de Pago DNA recibido
v_cod_moneda        varchar2(50);  --Codigo de Moneda IT
v_tot_pagar         varchar2(50);  --Total a Pagar
v_estado            varchar2(10);  --Estado de la Operacion(ENC(En curso)/ANU(anulado)/VEN(vencimiento))
v_fec_vto           varchar2(30);  --Fecha Vencimiento DNA
v_fec_vto_it        date;          --Fecha Vencimiento formato IT
v_fec_cre           varchar2(30);  --Fecha Creacion DNA
v_fec_cre_it        date;          --Fecha Creacion IT
v_cod_mon_origen    varchar2(10);  --Moneda Origen (IT)
v_mto_origen        number(20,4);  --Monto de Origen
v_sal_origen        number(20,4);  --Saldo de Origen
v_cod_mon_it        varchar2(50);
v_hab_con_dna     VARCHAR2(50) := nvl(fug_obt_pardinamico('HAB_CON_DNA'),'S');
v_nro_doc_dna       varchar2(100);
v_tip_doc_dna       varchar2(100);
v_tip_doc_it        varchar2(100);
v_raz_social        varchar2(200);
v_canal             varchar2(30);
v_guion             number(10);
v_dig_verificador   varchar2(10);
v_parte1            varchar2(30);
v_parte2            varchar2(30);
v_nro_documento   varchar2(30);
--
v_cod_persona      ba_personas.cod_persona%type;
v_nro_doc_cli      varchar2(100);
v_tip_doc_cli      varchar2(20);

BEGIN
   /********** Inicio de Proceso Principal *********/
   v_error:= null;
   v_respuesta:= 0;
   BEGIN PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1; END;
if UPPER(v_hab_con_dna) ='S' THEN   
   PRE_CAM_FOR_NUMERICO('.,');
   v_lugar:= 'Buscando Canal';
   if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
      v_canal:= 'HBANK';
    else
      v_canal:='CORE';
    end if;
     --Buscamos el codigo de Persona del cliente
     v_cod_persona:= null;
     begin
         select a.cod_persona
          into v_cod_persona
           from ba_personas a
            where a.nro_documento= p_nro_documento
               and a.cod_tip_documento= p_tip_documento;
       exception
         when no_data_found then
           v_cod_persona:= null;
         when others then
           v_cod_persona:= null;
       end;
    --*********02/06/2019 Ajuste para clientes con otro tip doc dna
    v_nro_doc_cli:= null;
    v_tip_doc_cli:= null;
     begin
         select a.nro_documento,a.cod_tip_documento
          into v_nro_doc_cli, v_tip_doc_cli
           from ba_per_documentos a
            where a.cod_persona= v_cod_persona
              and nvl(a.dna,'N')='S'
                and rownum=1;
       exception
         when no_data_found then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
         when others then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
       end;  
       --Sino encontramos en la tabla se asume lo recibido
       if v_nro_doc_cli is null and  v_tip_doc_cli is null then
          v_nro_doc_cli:=p_nro_documento;
          v_tip_doc_cli:= p_tip_documento;
       end if;
    --***********FIN DE AJUSTE   

     v_lugar:= 'Buscando Tipo de Documento';
       begin
         select upper(a.abreviatura)
          into v_tip_doc_dna
           from ba_tip_documentos a
            where a.cod_tip_documento= v_tip_doc_cli/*p_tip_documento*/;
       exception
         when no_data_found then
           v_tip_doc_dna:= null;
         when others then
           v_tip_doc_dna:= null;
       end;

   --Se envian tipo de documento RUC (Con digito verificador) /CI /OTR 
     if v_tip_doc_dna <> 'RUC' THEN
        if v_tip_doc_dna <> 'CI' then
           v_tip_doc_dna:='OTR';
        end if;
        --Se ajusta para enviar RUC si es contribuyente
        IF v_tip_doc_dna = 'CI' THEN
          --Solo se ajusta si es contribuyente, sino se envia tal cual
          IF nvl(FUE_OBT_PER_TIP_IVA(v_cod_persona),'NC')= 'CO' then
             v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*p_nro_documento*/);
             v_nro_documento:= v_nro_doc_cli/*p_nro_documento*/||v_dig_verificador;   
             v_tip_doc_dna :='RUC';
          else
             v_nro_documento:=v_nro_doc_cli/*p_nro_documento*/;
          end if;
        ELSE
          --Para otros documentos se envia tal cual
          v_nro_documento:=v_nro_doc_cli/*p_nro_documento*/;        
        END IF;
     elsif  v_tip_doc_dna='RUC' THEN
          v_guion:= instr(v_nro_doc_cli/*p_nro_documento*/,'-');
          if v_guion = 0 then
            --No tiene guion, agregamos el digito verificador al final
            v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*p_nro_documento*/);
            v_nro_documento:= v_nro_doc_cli/*p_nro_documento*/||v_dig_verificador;
          else
            --Ya se recibe con guion
            v_parte1:=  substr(v_nro_doc_cli/*p_nro_documento*/,1,v_guion-1);
            v_parte2:=  substr(v_nro_doc_cli/*p_nro_documento*/,v_guion+1,1);
            v_nro_documento:= v_parte1||v_parte2;
          end if;
     END IF;  
   --Validamos Orden de Pago
   v_lugar:= 'Validamos Orden de Pago';
   if p_nro_ord_pago is null then
      v_respuesta:=20;
      v_error:= 'CAMPO ID ORDEN DE PAGO NULO';
   elsif length(trim(p_nro_ord_pago)) <> 16 then
      v_respuesta:=21;
      v_error:= 'CAMPO ID ORDEN DE PAGO DEBE TENER LONGITUD 16';
   end if;

 v_lugar:= 'llamando al ws de consulta de Boletas de Pago';
 if  to_number(v_respuesta)= 0 then
      v_lugar:= 'Cargando URL JSON';
      v_url := g_dna_webservice || c_ws_metodo;
      v_lugar:= 'Cargando Parametros';
      v_parametros := utl_lms.format_message('accessToken=%s&idOrdenPago=%s&tipoDocumento=%s&nroDocumento=%s',g_api_gateway, utl_url.escape(p_nro_ord_pago), utl_url.escape(v_tip_doc_dna), utl_url.escape(v_nro_documento));
      v_lugar:= 'Enviando env Pos';
      v_resPost := fue_env_post(p_parametros => v_parametros, p_url => v_url);
   IF (v_resPost.error = 'N') THEN
      v_lugar:= 'Seteando resp. de Pos';
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      v_cod_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'codigoRetorno');
      v_des_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'descripcionRetorno');
      v_nro_doc_dna:= paw_json.getAttrValue(v_ws_respuesta, 'nroDocumento');
      v_tip_doc_dna:=  paw_json.getAttrValue(v_ws_respuesta, 'tipoDocumento');
      v_cod_mon_origen:=paw_json.getAttrValue(v_ws_respuesta, 'monedaOrigen');
      v_raz_social:= paw_json.getAttrValue(v_ws_respuesta, 'razonSocial');
      v_estado:=paw_json.getAttrValue(v_ws_respuesta, 'estado');
      v_fec_vto:=paw_json.getAttrValue(v_ws_respuesta, 'fechaVencimiento');
      v_fec_cre:=paw_json.getAttrValue(v_ws_respuesta, 'fechaArribo');
      v_mto_origen:=paw_json.getAttrValue(v_ws_respuesta, 'montoOrigen');
      v_sal_origen:=paw_json.getAttrValue(v_ws_respuesta, 'saldoOrigen');

      if v_des_retorno is null and v_cod_retorno is null  then
          p_estado            := null;
          p_fec_vencimiento   := null;
          p_fec_creacion      := null;
          p_cod_mon_origen    := null;
          p_razon_social      := null;
          p_mto_origen        := null;
          p_sal_origen        := null;
          p_tip_doc_pagador   := null;
          p_nro_doc_pagador   := null;
          if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
             v_error:= 'ERROR INTERNO...';
             v_respuesta:= 3;
          else
             --Se mejora mensaje de Salida para ITGF
             v_error:= 'Servicio de Consulta a DNA con inconvenientes!! Intente mas tarde!!';
             v_respuesta:= 3;
          end if; 
      end if;

      IF TO_NUMBER(nvl(v_cod_retorno,0))<> 0 then
          p_estado            := null;
          p_fec_vencimiento   := null;
          p_fec_creacion      := null;
          p_cod_mon_origen    := null;
          p_razon_social      := null;
          p_mto_origen        := null;
          p_sal_origen        := null;
          p_tip_doc_pagador   := null;
          p_nro_doc_pagador   := null;
          v_error             := v_des_retorno;
          v_respuesta         := v_cod_retorno;
      end if;

   --Buscamos el tipo de documento valido para IT
   v_lugar:='Buscamos el tipo de documento valido para IT';
   if to_number(v_respuesta)= 0 then
          begin
             select a.cod_tip_documento
              into v_tip_doc_it
               from ba_tip_documentos a
                where a.abreviatura= v_tip_doc_dna;
          exception
             when no_data_found then
                v_tip_doc_it:= null;
             when others then
                v_tip_doc_it:= null;
          end;
          --dbms_output.put_line(v_resPost.respuesta);
          v_lugar:= 'Buscando Codigo de Moneda de ITGF';
          v_respuesta:= 0;
          --Buscamos codigo de moneda ITGF
           begin
             select a.cod_moneda
              into v_cod_mon_it
               from ba_monedas a
                where UPPER(a.cod_mon_iso)= upper(v_cod_mon_origen);
           exception
             when no_data_found then
                v_cod_mon_it:= null;
             when others then
                v_cod_mon_it:= null;
           end;
          v_lugar:= 'Armando fecha de vencimiento IT';
          v_fec_vto_it:= to_date((substr(v_fec_vto,7,2)||'/'||substr(v_fec_vto,5,2) ||'/'||substr(v_fec_vto,1,4)),'dd/mm/yyyy');

          v_lugar:= 'Armando fecha de creacion IT';
          v_fec_cre_it:= to_date((substr(v_fec_cre,7,2)||'/'||substr(v_fec_cre,5,2) ||'/'||substr(v_fec_cre,1,4)),'dd/mm/yyyy');

          v_lugar:= 'Validando fecha de vencimiento IT';
          if trunc(v_fec_vto_it) < trunc(v_fec_actual) then
             v_respuesta:= -1;
             v_error:='La fecha de vencimiento de la Operacion en DNA es menor a Hoy';
          end if;

          v_lugar:= 'Validando Estado DNA';
          if upper(v_estado) = 'ANU'  then
             v_respuesta:= -2;
             v_error:='La operaci¿n esta en estado Anulada ';
          elsif upper(v_estado) = 'VEN'  then
             v_respuesta:= -3;
             v_error:='La operaci¿n esta en estado Vencida ';
          end if;

          v_lugar:= 'Validando Monedas DNA/BBVA';
          if p_cod_mon_tte is not null then
            if v_cod_mon_it <> p_cod_mon_tte then
               v_respuesta:= -4;
               v_error:='La moneda ingresada: '||p_cod_mon_tte|| ' difiere de la registrada en DNA: '|| v_cod_mon_it;
            end if;
          end if;

          v_lugar:= 'Validando Monto DNA/BBVA';
          if nvl(p_mto_tte,0) <> 0 then
            if NVL(p_mto_tte,0) <> NVL(v_mto_origen,0) then
               v_respuesta:= -5;
               v_error:='El monto de la TTE: '||p_mto_tte|| ' difiere de lo registrado en DNA: '|| v_mto_origen;
            end if;
          end if;

    end if;
      if  to_number(v_respuesta)= 0 then
          --Seteamos output
          v_lugar             := 'Cargando respuesta oK';
          p_estado            := v_estado;  --Estado de la Operacion(ENC(En curso)/ANU(anulado)/VEN(vencimiento))
          p_fec_vencimiento   := v_fec_vto_it;
          p_fec_creacion      := v_fec_cre_it;
          p_cod_mon_origen    := v_cod_mon_it;    --Moneda Origen (IT)
          p_mto_origen        := v_mto_origen;    --Monto de Origen
          p_sal_origen        := v_sal_origen;    --Saldo de Origen
          p_tip_doc_pagador   := v_tip_doc_it;
          p_nro_doc_pagador   := v_nro_doc_dna;
          p_razon_social      := upper(v_raz_social);
          v_error             := null;
          v_respuesta         := 0;
      end if;
   ELSE
      --Seteamos output
      v_lugar:= 'Cargando respuesta por Error';
      p_estado            :=null;
      p_fec_vencimiento   :=null;
      p_fec_creacion      :=null;
      p_cod_mon_origen    := null;    --Moneda Origen (IT)
      p_razon_social      := null;
      p_mto_origen        := null;    --Monto de Origen
      p_sal_origen        := null;    --Saldo de Origen
      p_tip_doc_pagador   := null;
      p_nro_doc_pagador   := null;
      if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
             v_error:= 'ERROR INTERNO.';
             v_respuesta:= 3;
      else
             --Se mejora mensaje de Salida para ITGF
             v_error:= 'Servicio de Consulta a DNA con inconvenientes!! Intente mas tarde!!';
             v_respuesta:= 3;
      end if;
   end if;

 end if;

  v_lugar:= 'Insertando en tabla de consulta de Boletas de Pago';
  if to_number(v_respuesta)= 0 then
     v_hora:= to_char(sysdate,'hh24:mi:ss');
     INSERT INTO LC_CON_BOL_OPE_DNA(cod_ord_ope,
                              fecha_env,
                              hora_env,
                              tip_documento,
                              nro_documento,
                              cod_moneda,
                              fec_creacion,
                              fec_vencimiento,
                              tot_pago,
                              cotizacion,
                              fecha_res,
                              hora_res,
                              estado ,
                              mensaje ,
                              respuesta,
                              observacion,
                              tip_consulta,
                              mon_origen,
                              mto_origen,
                              sal_origen,
                              raz_social)
                        values(p_nro_ord_pago,
                              v_fec_actual,
                              v_hora,
                              v_tip_doc_dna,
                              v_nro_documento,
                              p_cod_mon_origen,
                              p_fec_creacion,
                              p_fec_vencimiento,
                              null,
                              null,
                              sysdate,
                              v_hora,
                              p_estado,
                              v_parametros,
                              v_resultado,
                              null,
                              'OPE',
                              v_cod_mon_it,
                              p_mto_origen,
                              p_sal_origen,
                              upper(v_raz_social)
                              );
              --se comitea si es en el core (para Hbank no)
              if v_canal = 'CORE' then
                 commit;
              end if;

   end if;
   p_respuesta:= to_number(v_respuesta);
   p_msj_error:= v_error;
else
   p_respuesta:= 0;
   p_msj_error:= null;
end if;

EXCEPTION
  when others then
    p_respuesta:= v_respuesta;
    p_msj_error:= 'C.O.E.: '||p_nro_ord_pago||'-'||v_lugar||'- '||sqlerrm;

END;

--Inserci¿n de Registros de Transferencias enviadas a DNA
PROCEDURE PR_ENV_REG_TRA_DNA
( p_nro_referencia      in number default null,   --Nro referencia IT
  p_cod_tip_referencia  in varchar2 default null, --cod_tip_referencia IT
  p_nro_ref_externa     in varchar2 default null, --Nro ref. externa IT
  --Respuesta de Servicio
  p_respuesta           out number,  --Respuesta 0 sino hubo errores, sino error
  p_msj_error           out varchar2 --Mensaje de Error si Hubo

)IS
/*Procedimiento que inserta regitro de transferencias enviadas a DNA
Fecha
 Formato: YYYYMMDD
   Composici¿n:
    4d¿gitosparaela¿o o 2d¿gitosparaelmes o 2d¿gitosparaeld¿a
Fecha / Hora
 Formato: YYYYMMDDHHMMSS
  Composici¿n:
   4 d¿gitosparaela¿o
   2 d¿gitosparaelmes
   2 d¿gitosparaeld¿a
   2 d¿gitosparalahora
   2 d¿gitosparalosminutos
   2 d¿gitosparalossegundos
Formato de N¿meros Enteros
 Formato: DDDDDDDDD
  Composici¿n:
   9 d¿gitosenteros
Formato de N¿meros Reales
 Formato: DDDDDDDDD.DDD
 Composici¿n:
   9 d¿gitosenteros
   3 d¿gitosdecimales
*********Respuestas DNA *****************
00  OPERACION FINALIZADA EXITOSAMENTE
01  ATRIBUTO INVALIDO
02  USUARIO NO AUTENTICADO
03  ERROR INTERNO
04  DATOS NO ENCONTRADOS
10  ORDEN DE PAGO NO EXISTE
11  ORDEN DE PAGO VENCIDA
12  ORDEN DE PAGO NO DISPONIBLE PARA SU UTILIZACION
20  CAMPO ID ORDEN DE PAGO NULO
21  CAMPO ID ORDEN DE PAGO DEBE TENER LONGITUD 16
22  CAMPO NUMERO DE OPERACION NULO
23  CAMPO NUMERO DE OPERACION DEBE TENER LONGITUD MAXIMA 20
24  CAMPO CODIGO DE ENTIDAD FINANCIERA ORIGEN NULO
25  CAMPO CODIGO DE ENTIDAD FINANCIERA ORIGEN DEBE TENER LONGITUD MAXIMA 4
26  CAMPO TIPO DE DOCUMENTO DEL PAGADOR NULO
27  CAMPO TIPO DE DOCUMENTO DEL PAGADOR DEBE TENER LONGITUD MAXIMA 3
28  CAMPO NUMERO DE DOCUMENTO DEL PAGADOR NULO
29  CAMPO NUMERO DE DOCUMENTO DEL PAGADOR DEBE TENER LONGITUD MAXIMA 30
30  CAMPO NUMERO DE CUENTA DEL PAGADOR NULO
31  CAMPO NUMERO DE CUENTA DEL PAGADOR DEBE TENER LONGITUD MAXIMA 16
32  CAMPO CODIGO DE ENTIDAD FINANCIERA DESTINO NULO
33  CAMPO CODIGO DE ENTIDAD FINANCIERA DESTINO DEBE TENER LONGITUD MAXIMA 50
34  CAMPO PAIS DE ENTIDAD FINANCIERA DESTINO NULO
35  CAMPO PAIS DE ENTIDAD FINANCIERA DESTINO DEBE TENER LONGITUD 2
36  CAMPO CIUDAD DE ENTIDAD FINANCIERA DESTINO NULO
37  CAMPO CIUDAD DE ENTIDAD FINANCIERA DESTINO DEBE TENER LONGITUD MAXIMA 50
38  CAMPO PAIS DEL BENEFICIARIO DE LA TRANSFERENCIA NULO
39  CAMPO PAIS DEL BENEFICIARIO DE LA TRANSFERENCIA DEBE TENER LONGITUD 2
40  CAMPO NRO CUENTA DEL BENEFICIARIO DE LA TRANSFERENCIA NULO
41  CAMPO NRO CUENTA DEL BENEFICIARIO DE LA TRANSFERENCIA DEBE TENER LONGITUD MAXIMA 50
42  CAMPO NOMBRE DEL BENEFICIARIO DE LA TRANSFERENCIA NULO
43  CAMPO NOMBRE DEL BENEFICIARIO DE LA TRANSFERENCIA DEBE TENER LONGITUD MAXIMA 300
44  CAMPO IMPORTE DE LA TRANSFERENCIA NULO
45  CAMPO IMPORTE DE LA TRANSFERENCIA DEBE TENER LONGITUD MAXIMA 19 CON DOS DECIMALES
46  CAMPO MONEDA DE LA TRANSFERENCIA NULO
47  CAMPO MONEDA DE LA TRANSFERENCIA DEBE TENER LONGITUD 3
48  CAMPO FECHA DE LA TRANSFERENCIA NULO
49  CAMPO FECHA DE LA TRANSFERENCIA DEBE TENER LONGITUD 14
50  CAMPO ID DE OPERACION NULO
51  CAMPO ID DE OPERACION DEBE TENER LONGITUD 16
52  CAMPO TIPO DE DOCUMENTO NULO
53  CAMPO TIPO DE DOCUMENTO DEBE TENER LONGITUD 3
54  CAMPO NRO DE DOCUMENTO NULO
55  CAMPO NRO DE DOCUMENTO DEBE TENER LONGITUD MAXIMA 11
56  CAMPO OBSERVACION NULO
57  CAMPO OBSERVACION DEBE TENER LONGITUD MAXIMA 500
*/
v_lugar                varchar2(4000);
v_cod_usuario          ge_movimientos.cod_usuario%type:=USER;
v_fec_actual           date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
v_hora                 varchar2(10);
v_cod_ent         varchar2(4):= fug_obt_cod_entidad; --Cod.de Entidad Bancaria 
v_nro_cta_sipap        varchar2(16);
v_tip_doc_dna          varchar2(16);
v_cod_mon_dna          varchar2(100);
--Datos a Ser enviados a DNA
v_nro_referencia       number(10);   --Nro referencia IT
v_cod_tip_referencia   varchar2(10); --cod_tip_referencia IT
v_nro_ref_externa      varchar2(50); --Nro ref. externa IT
v_nro_operacion        number(20);   --Nro.Operacion IT
v_fecha                date;    --Fecha de la Transferencia
v_monto                number(20,4);   --Importe de la Transferencia
v_cod_moneda           varchar2(10); --Codigo de moneda ITGF
v_nro_ope_banco        varchar2(10); --Nro Operacion cambios 1
v_nro_ope_banco1       varchar2(10); --Nro Operacion cambios 2
v_nro_ope_banco_dna    varchar2(50); --Nro Operacion Banco(fecha/BIC/Campo 20 swift)
v_nro_ord_pago         varchar2(100);   --Nro Orden de Pago DNA
v_nro_cta_debito       varchar2(10); --Nro de Cta de Debito IT
v_cod_swi_bco_dna      varchar2(100); --Cod banco destino Swift(COD_SWI_BANCO IT)
v_cod_pai_bco_dna      varchar2(100); --Cod Pais de l Banco destino dna
v_cod_ciu_ben_dna      varchar2(100); --Cod Ciudad del Beneficiario dna
v_cod_pai_ben_dna      varchar2(10); --Cod Pais del Beneficiario dna
v_nro_cta_ben_destino  varchar2(30); --Nro cuenta o IBAN del Beneficiario IT
v_nom_beneficiario     varchar2(100); --Nombre del beneficiario (Proveedor)
v_cod_per_solicitante  varchar2(50); --C¿digo de Persona del solicitante IT
v_canal                varchar2(10); --Canal (HBANK/CORE)
v_observacion          varchar2(3000); --Observacion
v_usu_insercion        varchar2(100);
v_cod_tip_documento    varchar2(10);
v_nro_documento        varchar2(30);
v_nro_doc_cliente        varchar2(30);
v_cod_pai_bco_des_dna  varchar2(100);
v_cod_ciu_bco_des_dna  varchar2(100);
v_nom_bco_destino      varchar2(100);
v_cod_pai_bco_destino  varchar2(30); --ITGF
v_cod_ciu_bco_destino  varchar2(30); --ITGF
v_cod_pai_ben_destino  varchar2(30); --ITGF
v_cod_ciu_ben_destino  varchar2(30); --ITGF
v_importe_dna          varchar2(30);
v_entero_dna           varchar2(30);
v_real_dna             varchar2(30);
v_imp_dna              varchar2(30);
v_fecha_dna            varchar2(30);
v_error                varchar2(4500);
v_con_enviada          varchar2(5000);
--JSON
v_parametros           VARCHAR2(3000);
v_respuesta            VARCHAR2(10):=0;
c_ws_metodo            CONSTANT VARCHAR2(50) := fug_obt_pardinamico('URL_ENV_TRA_INT_DNA');--:= '/serv/bcp/consult_operation';
v_hab_con_dna     VARCHAR2(50) := nvl(fug_obt_pardinamico('HAB_CON_DNA'),'S');
v_url                  VARCHAR2(100) := '';
v_ws_respuesta         paw_json.JSONStructObj;
v_errorPost            VARCHAR2(1);
v_resPost              TYP_POSTRESPUESTA;
v_resultado            varchar2(4500);
v_cod_retorno          varchar2(4500);
v_des_retorno          varchar2(4500);
v_longitud             number(10);
v_decimal              number(10);
v_diferencia           number(10);
v_enviado              number(10):=0;
v_lon_dna              number(10);
v_cod_sofia            varchar2(30);
v_guion           number(10);
v_dig_verificador varchar2(10);
v_parte1           varchar2(30);
v_parte2           varchar2(30);
--
v_cod_persona      ba_personas.cod_persona%type;
v_nro_doc_cli      varchar2(100);
v_tip_doc_cli      varchar2(20);
begin
   /********** Inicio de Proceso Principal *********/
   -- NLS B.D.
   PRE_CAM_FOR_NUMERICO('.,');
   BEGIN PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1; END;
if UPPER(v_hab_con_dna) ='S' THEN   
   v_error:=null;
   v_nro_ref_externa:=null;
   if p_nro_ref_externa is null then
      v_nro_ref_externa:= trim(trim(p_cod_tip_referencia)||'/'||trim(p_nro_referencia));
   else
      v_nro_ref_externa:= p_nro_ref_externa;
   end if;
   v_lugar :='Validar In';
   if p_nro_referencia is null and p_cod_tip_referencia is null and p_nro_ref_externa is null  then
      v_respuesta:='-1';
      v_error:= 'LOS PARAMETROS NO PUEDEN SER NULOS';
   end if;

    if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
      v_canal:= 'HBANK';
    else
      v_canal:= 'CORE';
    end if;

   --Buscamos si ya no se envio antes de hacer nada
    v_enviado:=0;
    Begin
      select nvl(count(*),0)
         into v_enviado
           from lc_reg_transferencias a
             where a.nro_referencia= p_nro_referencia
               and a.cod_tip_referencia= p_cod_tip_referencia;
    exception
       when no_data_found then
          v_enviado:=0;
       when others then
          v_enviado:=0;
    END;

    if v_enviado > 0 then
       --Se devuelve 1, no se va a volver a enviar
       v_respuesta:=1;
       v_error:= 'Nro de Op. ya enviado a DNA';
    else
       v_respuesta:=0;
    end if;


 if to_number(v_respuesta)=  0 then
    v_lugar :='Buscar datos de la transferencia:' ||p_nro_ref_externa;
    --Obtenemos los datos de la Transferencia y enviamos a DNA
    Begin
      v_lugar:='Buscar datos de Transferencias';
      Select
          a.nro_referencia,       --Nro referencia IT
          a.cod_tip_referencia,   --cod_tip_referencia IT
          a.nro_ref_externa,      --Nro ref. externa IT
          a.nro_operacion,        --Nro.Operacion IT
          a.FEC_OPERACION,        --Fecha de la Transferencia
          a.monto,                --Importe de la Transferencia
          a.cod_moneda,           --Codigo de moneda ITGF
          a.nro_operacion,        --Nro Operacion Banco
          a.nro_operacion2,       --Nro Operacion Banco
          a.nro_ord_pag_dna,      --Nro Orden de Pago DNA
          trim(substr(a.nom_banco,1,50)), --Cod banco destino Swift(COD_SWI_BANCO IT)
          a.cod_ciu_banco,        --Cod Ciudad del Banco destino IT
          a.cod_pai_banco,        --Cod Pais de l Banco destino IT
          a.cod_ciu_beneficiario, --Cod Ciudad del Beneficiario IT
          a.cod_pai_beneficiario, --Cod Pais del Beneficiario IT
          a.Nro_Cta_Referencia,   --Nro de cuenta del beneficiario
          a.usu_insercion,
          a.nom_beneficiario,
          a.nro_cta_debito,
          a.cod_per_solicitante
        into
          v_nro_referencia,      --Nro referencia IT
          v_cod_tip_referencia,  --cod_tip_referencia IT
          v_nro_ref_externa,     --Nro ref. externa IT
          v_nro_operacion,       --Nro.Operacion IT
          v_fecha,               --Fecha de la Transferencia
          v_monto,               --Importe de la Transferencia
          v_cod_moneda,          --Codigo de moneda ITGF
          v_nro_ope_banco,       --Nro Operacion Banco
          v_nro_ope_banco1,      --Nro Operacion Banco
          v_nro_ord_pago,        --Nro Orden de Pago DNA
          v_nom_bco_destino,     --Cod banco destino Swift(COD_SWI_BANCO IT)
          v_cod_ciu_bco_destino, --Cod Ciudad del Banco destino IT
          v_cod_pai_bco_destino, --Cod Pais de l Banco destino IT
          v_cod_ciu_ben_destino, --Cod Ciudad del Beneficiario IT
          v_cod_pai_ben_destino, --Cod Pais del Beneficiario IT
          v_nro_cta_ben_destino,
          v_usu_insercion,
          v_nom_beneficiario,
          v_nro_cta_debito,
          v_cod_per_solicitante
           from lc_transferencias a
              where a.nro_referencia= nvl(p_nro_referencia, a.nro_referencia)
                and a.cod_tip_referencia= nvl(p_cod_tip_referencia, a.cod_tip_referencia)
                and a.nro_ref_externa= nvl(v_nro_ref_externa, a.nro_ref_externa);
     exception
       when no_data_found then
          begin
                 Select
                    a.nro_referencia,       --Nro referencia IT
                    a.cod_tip_referencia,   --cod_tip_referencia IT
                    a.nro_ref_externa,      --Nro ref. externa IT
                    a.nro_operacion,        --Nro.Operacion IT
                    a.FEC_OPERACION,        --Fecha de la Transferencia
                    a.monto,                --Importe de la Transferencia
                    a.cod_moneda,           --Codigo de moneda ITGF
                    a.nro_operacion,        --Nro Operacion Banco
                    a.nro_operacion2,       --Nro Operacion Banco
                    a.nro_ord_pag_dna,      --Nro Orden de Pago DNA
                    trim(substr(a.nom_banco,1,50)), --Cod banco destino Swift(COD_SWI_BANCO IT)
                    a.cod_ciu_banco,        --Cod Ciudad del Banco destino IT
                    a.cod_pai_banco,        --Cod Pais de l Banco destino IT
                    a.cod_ciu_beneficiario, --Cod Ciudad del Beneficiario IT
                    a.cod_pai_beneficiario, --Cod Pais del Beneficiario IT
                    a.Nro_Cta_Referencia,   --Nro de cuenta del beneficiario
                    a.usu_insercion,
                    a.nom_beneficiario,
                    a.nro_cta_debito,
                    a.cod_per_solicitante
                  into
                    v_nro_referencia,      --Nro referencia IT
                    v_cod_tip_referencia,  --cod_tip_referencia IT
                    v_nro_ref_externa,     --Nro ref. externa IT
                    v_nro_operacion,       --Nro.Operacion IT
                    v_fecha,               --Fecha de la Transferencia
                    v_monto,               --Importe de la Transferencia
                    v_cod_moneda,          --Codigo de moneda ITGF
                    v_nro_ope_banco,       --Nro Operacion Banco
                    v_nro_ope_banco1,      --Nro Operacion Banco
                    v_nro_ord_pago,        --Nro Orden de Pago DNA
                    v_nom_bco_destino,     --Cod banco destino Swift(COD_SWI_BANCO IT)
                    v_cod_ciu_bco_destino, --Cod Ciudad del Banco destino IT
                    v_cod_pai_bco_destino, --Cod Pais de l Banco destino IT
                    v_cod_ciu_ben_destino, --Cod Ciudad del Beneficiario IT
                    v_cod_pai_ben_destino, --Cod Pais del Beneficiario IT
                    v_nro_cta_ben_destino,
                    v_usu_insercion,
                    v_nom_beneficiario,
                    v_nro_cta_debito,
                    v_cod_per_solicitante
                     from lc_tra_otr_monedas a
                        where a.nro_referencia= p_nro_referencia;
           exception
              when no_data_found then
                 v_respuesta:='4';
                 v_error:= 'DATOS NO ENCONTRADOS...:'||p_nro_referencia;
               WHEN OTHERS THEN
                      v_respuesta:='3';
                      v_error:= 'ERROR INTERNO..';
           end;


       when others then
           v_respuesta:='3';
           v_error:= 'ERROR INTERNO...';
     END;
  if v_respuesta=0 then
     --Obtenemos la cuenta de Debito de la operacion
     v_lugar:= 'Validando Orden de Pago';
     --Validamos Orden de Pago
     if v_nro_ord_pago is null then
        v_respuesta:=20;
        v_error:= 'CAMPO ID ORDEN DE PAGO NULO';
     elsif length(trim(v_nro_ord_pago)) <> 16 then
        v_respuesta:=21;
        v_error:= 'CAMPO ID ORDEN DE PAGO DEBE TENER LONGITUD 16';
     end if;
     --**************  ver que se hace **************
     v_lugar:= 'Validando Cta Debito';
     if v_nro_cta_debito is null then
          v_respuesta:=30;
          v_error:= 'CAMPO NUMERO DE CUENTA DEL PAGADOR NULO';
     end if;
     v_nro_cta_sipap:= pas_snp.fu_ver_cuenta(v_nro_cta_debito); 
     v_nro_cta_sipap:= lpad(v_nro_cta_sipap,16,'0');
     --Validamos Nro de Cta Sipap
     v_lugar:='Validamos Nro de Cta Deb.For.SIPAP';
     if v_nro_cta_sipap is null then
          v_respuesta:=30;
          v_error:= 'CAMPO NUMERO DE CUENTA DEL PAGADOR NULO';
     elsif nvl(length(trim(v_nro_cta_sipap)),0) > 16 then
          v_respuesta:=31;
          v_error:= 'CAMPO NUMERO DE CUENTA DEL PAGADOR DEBE TENER LONGITUD MAXIMA 16';
     end if;
     --**************************************************
     v_lugar:= 'Armando Cta DNA';
     --Nro Operacion Banco(fecha/BIC/Campo 20 swift)
     --v_nro_ope_banco_DNA:= to_char(v_fecha,'yyyymmdd')||'BBVAPYPA'||v_cod_tip_referencia||v_nro_referencia;
     --***********************
     v_lon_dna:= length(v_nro_referencia);
     if v_lon_dna=  6 then
       v_nro_ope_banco_DNA:= v_nro_referencia||to_char(v_fecha,'yyyymmdd');
     elsif  v_lon_dna < 6 then
       v_nro_ope_banco_DNA:= lpad(v_nro_referencia,6,0)||to_char(v_fecha,'yyyymmdd');
     else
       v_nro_ope_banco_DNA:= substr(v_nro_referencia,1,6)||to_char(v_fecha,'yyyymmdd');
     end if;
     --***********************
     --Validamos Orden de Pago
     if v_nro_ope_banco_DNA is null then
          v_respuesta:=22;
          v_error:= 'CAMPO NUMERO DE OPERACION NULO';
     elsif nvl(length(trim(v_nro_ope_banco_DNA)),0) > 20 then
          v_respuesta:=23;
          v_error:= 'CAMPO NUMERO DE OPERACION DEBE TENER LONGITUD MAXIMA 20';
     end if;
     --**************************************************
     v_lugar:= 'Buscando datos del solicitante: '||v_cod_per_solicitante;
        Begin

          Select a.cod_tip_documento, a.nro_documento
            into v_cod_tip_documento, v_nro_doc_cliente
            from ba_personas A
           where a.cod_persona= v_cod_per_solicitante;
        exception
           when no_data_found then
              v_respuesta:='4';
              v_error:= 'DATOS NO ENCONTRADOS...';
           when others then
               v_respuesta:='3';
               v_error:= 'ERROR INTERNO...';
        END;
        
        --*********02/06/2019 Ajuste para clientes con otro tip doc dna
    v_nro_doc_cli:= null;
    v_tip_doc_cli:= null;
     begin
         select a.nro_documento,a.cod_tip_documento
          into v_nro_doc_cli, v_tip_doc_cli
           from ba_per_documentos a
            where a.cod_persona= v_cod_per_solicitante
              and nvl(a.dna,'N')='S'
                and rownum=1;
       exception
         when no_data_found then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
         when others then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
       end;  
       --Sino encontramos en la tabla se asume lo recibido
       if v_nro_doc_cli is null and  v_tip_doc_cli is null then
          v_nro_doc_cli:=v_nro_doc_cliente;
          v_tip_doc_cli:= v_cod_tip_documento;
       end if;
    --***********FIN DE AJUSTE

       v_lugar:= 'Buscando Tipo de Documento';
       begin
         select upper(a.abreviatura)
          into v_tip_doc_dna
           from ba_tip_documentos a
            where a.cod_tip_documento= v_tip_doc_cli/*v_cod_tip_documento*/;
       exception
         when no_data_found then
           v_tip_doc_dna:= null;
         when others then
           v_tip_doc_dna:= null;
       end;
       --Se envian tipo de documento RUC (Con digito verificador) /CI /OTR 
     if v_tip_doc_dna <> 'RUC' THEN
        if v_tip_doc_dna <> 'CI' then
           v_tip_doc_dna:='OTR';
        end if;
           --Se ajusta para enviar RUC si es contribuyente
        IF v_tip_doc_dna = 'CI' THEN
          --Solo se ajusta si es contribuyente, sino se envia tal cual
          IF nvl(FUE_OBT_PER_TIP_IVA(v_cod_per_solicitante),'NC')= 'CO' then
             v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*v_nro_doc_cliente*/);
             v_nro_documento:= v_nro_doc_cli/*v_nro_doc_cliente*/||v_dig_verificador;   
             v_tip_doc_dna :='RUC';
          else
             v_nro_documento:=v_nro_doc_cli/*v_nro_doc_cliente*/;
          end if;
        ELSE
          --Para otros documentos se envia tal cual
          v_nro_documento:=v_nro_doc_cli/*v_nro_doc_cliente*/;        
        END IF;
     elsif  v_tip_doc_dna='RUC' THEN
          v_guion:= instr(v_nro_doc_cli/*v_nro_doc_cliente*/,'-');
          if v_guion = 0 then
            --No tiene guion, agregamos el digito verificador al final
            v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*v_nro_doc_cliente*/);
            v_nro_documento:= v_nro_doc_cli/*v_nro_doc_cliente*/||v_dig_verificador;
          else
            --Ya se recibe con guion
            v_parte1:=  substr(v_nro_doc_cli/*v_nro_doc_cliente*/,1,v_guion-1);
            v_parte2:=  substr(v_nro_doc_cli/*v_nro_doc_cliente*/,v_guion+1,1);
            v_nro_documento:= v_parte1||v_parte2;
          end if;
     END IF;  
     --Validamos Tipo de Documento
     v_lugar:='Validando tipo de documento DNA';
     if v_tip_doc_dna is null then
          v_respuesta:=26;
          v_error:= 'CAMPO TIPO DE DOCUMENTO DEL PAGADOR NULO';
     elsif nvl(length(trim(v_tip_doc_dna)),0) > 3 then
          v_respuesta:=27;
          v_error:= 'CAMPO TIPO DE DOCUMENTO DEL PAGADOR DEBE TENER LONGITUD MAXIMA 3';
     end if;

     v_lugar:='Validando Nro. de documento DNA';
     if v_nro_documento is null then
          v_respuesta:=28;
          v_error:= 'CAMPO NUMERO DE DOCUMENTO DEL PAGADOR NULO';
     elsif nvl(length(trim(v_nro_documento)),0) > 30 then
          v_respuesta:=29;
          v_error:= 'CAMPO NUMERO DE DOCUMENTO DEL PAGADOR DEBE TENER LONGITUD MAXIMA 30';
     end if;

       v_lugar:= 'Buscando Pais Swift de Banco destino';
       begin
         select a.cod_pai_iso
          into v_cod_pai_bco_des_dna
           from ba_paises a
            where a.cod_pais= v_cod_pai_bco_destino;
       exception
         when no_data_found then
           v_cod_pai_bco_des_dna:= null;
         when others then
           v_cod_pai_bco_des_dna:= null;
       end;

       v_lugar:= 'Buscando ciudad Swift de Banco destino';
       begin
         select substr(nvl(a.des_bco_central,a.descripcion),1,50)
          into v_cod_ciu_bco_des_dna
           from ba_ciudades a
            where a.cod_pais= v_cod_pai_bco_destino
              and a.cod_ciudad= v_cod_ciu_bco_destino;
       exception
         when no_data_found then
           v_cod_ciu_bco_des_dna:= null;
         when others then
           v_cod_ciu_bco_des_dna:= null;
       end;

       --Validamos Codigo de pais destino
       if v_cod_pai_bco_des_dna is null then
            v_respuesta:=34;
            v_error:= 'CAMPO PAIS DE ENTIDAD FINANCIERA DESTINO NULO';
       elsif nvl(length(trim(v_cod_pai_bco_des_dna)),0) <> 2 then
            v_respuesta:=35;
            v_error:= 'CAMPO PAIS DE ENTIDAD FINANCIERA DESTINO DEBE TENER LONGITUD 2';
       end if;
       v_lugar:= 'Validamos Codigo de ciudad destino';
       --Validamos Codigo de ciudad destino
       if v_cod_ciu_bco_des_dna is null then
            v_respuesta:=36;
            v_error:= 'CAMPO CIUDAD DE ENTIDAD FINANCIERA DESTINO NULO';
       elsif nvl(length(trim(v_cod_ciu_bco_des_dna)),0) > 50 then
            v_respuesta:=37;
            v_error:= 'CAMPO CIUDAD DE ENTIDAD FINANCIERA DESTINO DEBE TENER LONGITUD MAXIMA 50';
       end if;

       v_lugar:= 'Buscando Pais del beneficiario';
       begin
         select a.cod_pai_iso
          into v_cod_pai_ben_dna
           from ba_paises a
            where a.cod_pais= v_cod_pai_ben_destino;
       exception
         when no_data_found then
           v_cod_pai_ben_dna:= null;
         when others then
           v_cod_pai_ben_dna:= null;
       end;

       v_lugar:= 'Buscando ciudad Swift del beneficiario';
       begin
         select substr(nvl(a.des_bco_central,a.descripcion),1,50)
          into v_cod_ciu_ben_dna
           from ba_ciudades a
            where a.cod_pais= v_cod_pai_ben_destino
              and a.cod_ciudad= v_cod_ciu_ben_destino;
       exception
         when no_data_found then
           v_cod_ciu_ben_dna:= null;
         when others then
           v_cod_ciu_ben_dna:= null;
       end;

     --Validamos Codigo de pais beneficiario
     v_lugar:= 'Validamos Codigo de pais beneficiario';
     if v_cod_pai_ben_dna is null then
          v_respuesta:=38;
          v_error:= 'CAMPO PAIS DEL BENEFICIARIO DE LA TRANSFERENCIA NULO';
     elsif nvl(length(trim(v_cod_pai_ben_dna)),0) <> 2 then
          v_respuesta:=39;
          v_error:= 'CAMPO PAIS DEL BENEFICIARIO DE LA TRANSFERENCIA DEBE TENER LONGITUD 2';
     end if;

     v_lugar:= 'Buscando Moneda Iso';
     begin
       select a.cod_mon_iso
        into v_cod_mon_dna
         from ba_monedas a
          where a.cod_moneda= v_cod_moneda;
     exception
       when no_data_found then
         v_cod_mon_dna:= null;
       when others then
         v_cod_mon_dna:= null;
     end;
    v_lugar:= 'Buscando Canal';
    if substr(upper(v_usu_insercion),1,4) = 'HBAN' then
      v_canal:= 'HBANK';
    else
      v_canal:='CORE';
    end if;

    v_lugar:= 'Armando fecha dna';
    v_fecha_dna:= to_char(v_fecha,'yyyymmddhh24miss');
    --************ INICIO DE VALIDACION DE IMPORTE PARA DNA ************
    v_lugar:= 'Armando importe dna';
    v_importe_dna:= to_char(v_monto);
    if instr(to_char(v_importe_dna),'.')= 0 and instr(to_char(v_importe_dna),',')= 0 then
       v_entero_dna:= trim(v_importe_dna)||'.00';
       v_real_dna:= null;
    elsif instr(to_char(v_importe_dna),'.') > 0 then
       v_longitud:= length(trim(v_importe_dna));
       v_decimal:=  instr(to_char(v_importe_dna),'.');
       v_diferencia:= v_longitud - v_decimal;
       --Si es un decimal, se agrega un cero a la derecha
       if v_diferencia = 1 then
         v_real_dna:= trim(v_importe_dna)||'0';
         v_entero_dna:= null;
       --Si son 2 decimales, no se hace nada
       elsif v_diferencia = 2 then
         v_real_dna:= trim(v_importe_dna);
         v_entero_dna:= null;
       --Si son 2 o mas decimales, se corta y se envia 2
       elsif v_diferencia > 2 then
          v_real_dna:= substr(v_importe_dna,1,instr(v_importe_dna,'.')-1)||substr(v_importe_dna,instr(v_importe_dna,'.'),3 ) ;
          v_entero_dna:= null;
       end if;
    elsif instr(to_char(v_importe_dna),',') > 0 then
       v_longitud:= length(trim(v_importe_dna));
       v_decimal:=  instr(to_char(v_importe_dna),',');
       v_diferencia:= v_longitud - v_decimal;
       --Si es un decimal, se agrega un cero a la derecha
       if v_diferencia = 1 then
         v_real_dna:= trim(v_importe_dna)||'0';
         v_entero_dna:= null;
       --Si son 2 decimales, no se hace nada
       elsif v_diferencia = 2 then
         v_real_dna:= trim(v_importe_dna);
         v_entero_dna:= null;
       --Si son 2 o mas decimales, se corta y se envia 2
       elsif v_diferencia > 2 then
          v_real_dna:= substr(v_importe_dna,1,instr(v_importe_dna,',')-1)||substr(v_importe_dna,instr(v_importe_dna,','),3 ) ;
          v_entero_dna:= null;
       end if;
    end if;
    --************ FIN DE VALIDACION DE IMPORTE PARA DNA ************

     v_imp_dna:=trim(nvl(v_entero_dna,v_real_dna)) ;
     --Validamos Importe de la transferencia
     v_lugar:= 'Validamos Importe de la transferencia';
     if v_imp_dna is null then
          v_respuesta:=44;
          v_error:= 'CAMPO IMPORTE DE LA TRANSFERENCIA NULO';
     elsif nvl(length(trim(v_imp_dna)),0) > 19 then
          v_respuesta:=45;
          v_error:= 'CAMPO IMPORTE DE LA TRANSFERENCIA DEBE TENER LONGITUD MAXIMA 19 CON DOS DECIMALES';
     end if;
    ---**************************************************
     --Validamos Codigo de entidad financiera destino
     v_lugar:= 'Validamos Codigo de entidad financiera destino';
     if v_nom_bco_destino is null then
          v_respuesta:=32;
          v_error:= 'CAMPO CODIGO DE ENTIDAD FINANCIERA DESTINO NULO';
     elsif nvl(length(trim(v_nom_bco_destino)),0) > 50 then
          v_respuesta:=33;
          v_error:= 'CAMPO CODIGO DE ENTIDAD FINANCIERA DESTINO DEBE TENER LONGITUD MAXIMA 50';
     end if;

     v_lugar:= 'Validamos Nro.Cta.Benef.Destino';
      --Validamos Nro.Cat.Ben.Destino
     if v_nro_cta_ben_destino is null then
          v_respuesta:=40;
          v_error:= 'CAMPO NRO CUENTA DEL BENEFICIARIO DE LA TRANSFERENCIA NULO';
     elsif nvl(length(trim(v_nro_cta_ben_destino)),0) > 50 then
          v_respuesta:=41;
          v_error:= 'CAMPO NRO CUENTA DEL BENEFICIARIO DE LA TRANSFERENCIA DEBE TENER LONGITUD MAXIMA 50';
     end if;

     v_lugar:= 'Validamos Nombre de Beneficiario';
      --Validamos Nombre de Beneficiario
     if v_nom_beneficiario is null then
          v_respuesta:=42;
          v_error:= 'CAMPO NOMBRE DEL BENEFICIARIO DE LA TRANSFERENCIA NULO';
     elsif nvl(length(trim(v_nom_beneficiario)),0) > 300 then
          v_respuesta:=43;
          v_error:= 'CAMPO NOMBRE DEL BENEFICIARIO DE LA TRANSFERENCIA DEBE TENER LONGITUD MAXIMA 300';
     end if;

     --Validamos Moneda de la Transferencia
     v_lugar:= 'Validamos Moneda de la Transferencia';
     if v_cod_mon_dna is null then
          v_respuesta:=46;
          v_error:= 'CAMPO MONEDA DE LA TRANSFERENCIA NULO';
     elsif nvl(length(trim(v_cod_mon_dna)),0) <> 3 then
          v_respuesta:=47;
          v_error:= 'CAMPO MONEDA DE LA TRANSFERENCIA DEBE TENER LONGITUD 3';
     end if;
     --Validamos Fecha de la Transferencia
     v_lugar:= 'Validamos Fecha de la Transferencia';
     if v_fecha_dna is null then
          v_respuesta:=48;
          v_error:= 'CAMPO FECHA DE LA TRANSFERENCIA NULO';
     elsif nvl(length(trim(v_fecha_dna)),0) <> 14 then
          v_respuesta:=49;
          v_error:= 'CAMPO FECHA DE LA TRANSFERENCIA DEBE TENER LONGITUD 14';
     end if;

    --************Armando datos para el WS ***************************
   v_lugar:= 'llamando al ws de envio de transferencias al DNA';
   end if;
   if  v_respuesta= 0 then
      v_lugar:= 'Cargando URL JSON';
      v_url := g_dna_webservice || c_ws_metodo;
      v_lugar:= 'Cargando Parametros';

    v_parametros := utl_lms.format_message('accessToken=%s&id=%s&nroOperacion=%s&entidadOrigen=%s&tipDocumento=%s&nroDocumento=%s&nroCuenta=%s&entidadDestino=%s&paisDestino=%s&ciudadDestino=%s&paisBeneficiario=%s&ciudadBeneficiario=%s&cuentaBeneficiario=%s&nombreBeneficiario=%s&importe=%s&moneda=%s&fecha=%s',
    g_api_gateway, utl_url.escape(v_nro_ord_pago),utl_url.escape(v_nro_ope_banco_DNA),
    utl_url.escape(v_cod_ent),utl_url.escape(v_tip_doc_DNA),utl_url.escape(v_nro_documento),
    utl_url.escape(v_nro_cta_sipap),
    utl_url.escape(v_nom_bco_destino),utl_url.escape(v_cod_pai_bco_des_dna),
    utl_url.escape(v_cod_ciu_bco_des_dna), utl_url.escape(v_cod_pai_ben_dna),
    utl_url.escape(v_cod_ciu_ben_dna),
    utl_url.escape(v_nro_cta_ben_destino),utl_url.escape(v_nom_beneficiario),
    utl_url.escape(v_imp_dna),utl_url.escape(v_cod_mon_dna),utl_url.escape(v_fecha_dna)  );
    v_lugar:= 'Enviando env Pos';
    v_resPost := fue_env_post(p_parametros => v_parametros, p_url => v_url);
   IF (v_resPost.error = 'N') THEN
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      v_cod_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'codigoRetorno');
      v_des_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'descripcionRetorno');
      v_cod_sofia:= paw_json.getAttrValue(v_ws_respuesta, 'idTransaccionSofia');
      IF v_cod_retorno is null then
          if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
             v_error:= 'ERROR INTERNO...';
             v_respuesta:= 3;
          else
             --Se mejora mensaje de Salida para ITGF
             v_error:= 'Servicio de registro en DNA con inconvenientes!! Intente mas tarde!!';
             v_respuesta:= 3;
          end if;
      elsIF TO_NUMBER(nvl(v_cod_retorno,0)) <> 0 then
          v_resultado:= v_des_retorno;
          v_respuesta:= v_cod_retorno;
      else
        v_resultado:= v_des_retorno;
        v_respuesta:= 0;
      end if;

   ELSE
         if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
             v_error:= 'ERROR INTERNO.';
             v_respuesta:= 3;
          else
             --Se mejora mensaje de Salida para ITGF
             v_error:= 'Servicio de registro en DNA con inconvenientes!! Intente mas tarde!!';
             v_respuesta:= 3;
          end if;      
   END IF;

 end if;

     --**************************************************
     if v_respuesta= 0 then
         v_lugar:='Insertar en la tabla lc_reg_tranferencias';
         v_hora:= to_char(sysdate,'hh24:mi:ss');
         insert into LC_REG_TRANSFERENCIAS(nro_referencia ,
                                        cod_tip_referencia,
                                        nro_ref_externa,
                                        nro_operacion,
                                        fecha ,
                                        monto ,
                                        cod_moneda ,
                                        nro_ope_banco ,
                                        nro_ord_pago ,
                                        nro_doc_pagador ,
                                        tip_doc_pagador ,
                                        nro_cta_debito ,
                                        cod_bco_destino  ,
                                        cod_ciu_bco_destino ,
                                        cod_pai_bco_destino ,
                                        cod_ciu_ben_destino ,
                                        cod_pai_ben_destino ,
                                        nro_cta_ben_destino ,
                                        nom_beneficiario   ,
                                        estado ,
                                        cod_per_solicitante ,
                                        mensaje ,
                                        respuesta ,
                                        enviada   ,
                                        fecha_envio ,
                                        hor_envio     ,
                                        canal        ,
                                        observacion,
                                        cod_sofia)
                                  values(v_nro_referencia     , --Nro referencia IT
                                        v_cod_tip_referencia  , --cod_tip_referencia IT
                                        v_nro_ref_externa     , --Nro ref. externa IT
                                        v_nro_operacion       , --Nro.Operacion IT
                                        v_fecha               , --Fecha de la Transferencia
                                        v_monto               , --Importe de la Transferencia
                                        v_cod_moneda          , --Codigo de moneda ITGF
                                        v_nro_ope_banco       , --Nro Operacion Banco(fecha/BIC/Campo 20 swift)
                                        v_nro_ord_pago        , --Nro Orden de Pago DNA
                                        v_nro_documento    , --Nro de Documento Pagador
                                        v_cod_tip_documento     , --Tipo de Documento IT
                                        v_nro_cta_sipap      ,  --Nro de Cta de Debito (SIPAP)
                                        v_nom_bco_destino     , --Cod banco destino IT
                                        v_cod_ciu_bco_destino , --Cod Ciudad del Banco destino IT
                                        v_cod_pai_bco_destino , --Cod Pais de l Banco destino IT
                                        v_cod_ciu_ben_destino , --Cod Ciudad del Beneficiario IT
                                        v_cod_pai_ben_destino , --Cod Pais del Beneficiario IT
                                        v_nro_cta_ben_destino , --Nro cuenta o IBAN del Beneficiario IT
                                        v_nom_beneficiario    , --Nombre del beneficiario (Proveedor)
                                        'E', --estado
                                        v_cod_per_solicitante , --C¿digo de Persona del solicitante IT
                                        v_parametros,
                                        v_resultado,
                                        'S' , --Enviada
                                        sysdate, --fec_envio
                                        v_hora, --Hora de envio
                                        v_canal               , --Canal (HBANK/CORE)
                                        v_observacion,          --Observacion
                                        v_cod_sofia  );
              --se comitea si es en el core (para Hbank no)
              if v_canal = 'CORE' then
                 commit;
              end if;
       end if;
   --
 end if;

  p_respuesta:= to_number(v_respuesta);
  p_msj_error:= NVL(v_error,v_resultado);
else
   p_respuesta:= 0;
   p_msj_error:= null;
end if;

EXCEPTION
  when others then
    p_respuesta:= v_respuesta;
    p_msj_error:= 'G.T.T.E.: '||p_nro_referencia||'-'||v_lugar||'- '||sqlerrm;

END;



--Reversion de Ordenes de Pago DNA
PROCEDURE PR_REV_DNA
( p_id_operacion        in varchar2 default null,   --Nro Orden de Pago DNA
  p_nro_documento       in varchar2 default null,  --Nro de Documento
  p_tip_documento       in varchar2 default null,  --Tipo de Documento
  p_observacion         in varchar2 default null, -- Observacion
  --Respuesta de Servicio
  p_respuesta           out number, --respuesta 0 sino hubo errores, sino error
  p_msj_error           out varchar2 --Mensaje de Error si Hubo
)is
v_lugar varchar2(3000);
v_cod_usuario       ge_movimientos.cod_usuario%type:=USER;
v_fec_actual        date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
v_hora              varchar2(10);
v_tip_doc_dna       varchar2(100);
--JSON
v_parametros        VARCHAR2(3000);
v_respuesta         VARCHAR2(10):=0;
c_ws_metodo         CONSTANT VARCHAR2(50) := fug_obt_pardinamico('URL_REV_BOL_INT_DNA');
v_hab_con_dna       VARCHAR2(50) := nvl(fug_obt_pardinamico('HAB_CON_DNA'),'S');
v_url               VARCHAR2(100) := '';
v_ws_respuesta      paw_json.JSONStructObj;
v_errorPost         VARCHAR2(1);
v_resPost           TYP_POSTRESPUESTA;
v_resultado         varchar2(4500);
v_cod_retorno       varchar2(4500);
v_des_retorno       varchar2(4500);
v_error             varchar2(4000);
v_enviado           number(10):=0;
v_canal             varchar2(20);
v_guion           number(10);
v_dig_verificador varchar2(10);
v_parte1           varchar2(30);
v_parte2           varchar2(30);
v_nro_documento   varchar2(30);
--
v_cod_persona      ba_personas.cod_persona%type;	
v_nro_doc_cli      varchar2(100);
v_tip_doc_cli      varchar2(20);

BEGIN

   /********** Inicio de Proceso Principal *********/
   v_lugar:= 'Validando Datos';
   -- NLS B.D.
   PRE_CAM_FOR_NUMERICO('.,');
   BEGIN PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1; END;
if UPPER(v_hab_con_dna) ='S' THEN   
   if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
      v_canal:= 'HBANK';
    else
      v_canal:='CORE';
    end if;
	  --Buscamos el codigo de Persona del cliente
     v_cod_persona:= null;
     begin
         select a.cod_persona
          into v_cod_persona
           from ba_personas a
            where a.nro_documento= p_nro_documento
               and a.cod_tip_documento= p_tip_documento;
       exception
         when no_data_found then
           v_cod_persona:= null;
         when others then
           v_cod_persona:= null;
       end;
    --*********02/06/2019 Ajuste para clientes con otro tip doc dna
    v_nro_doc_cli:= null;
    v_tip_doc_cli:= null;
     begin
         select a.nro_documento,a.cod_tip_documento
          into v_nro_doc_cli, v_tip_doc_cli
           from ba_per_documentos a
            where a.cod_persona= v_cod_persona
              and nvl(a.dna,'N')='S'
                and rownum=1;
       exception
         when no_data_found then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
         when others then
            v_nro_doc_cli:= null;
            v_tip_doc_cli:= null;
       end;  
       --Sino encontramos en la tabla se asume lo recibido
       if v_nro_doc_cli is null and  v_tip_doc_cli is null then
          v_nro_doc_cli:=p_nro_documento;
          v_tip_doc_cli:= p_tip_documento;
       end if;
    --***********FIN DE AJUSTE    
   --Buscamos si ya no se envio antes de hacer nada- 02_06 No se valida
  /* v_enviado:=0;
   Begin
      select nvl(count(*),0)
         into v_enviado
           from lc_reg_transferencias a
             where upper(a.nro_ord_pago) = upper(p_id_operacion);
   exception
       when no_data_found then
          v_enviado:=0;
       when others then
          v_enviado:=0;
    END;

    if v_enviado > 0 then
        v_respuesta:=0;
    else
        v_respuesta:=1;
        v_error:= 'No se envio Orden de Pago a DNA';
    end if;*/

 if to_number(v_respuesta)= 0 then
     --Buscamos el tipo de documento valido para DNA
     begin
         select upper(a.abreviatura)
          into v_tip_doc_dna
           from ba_tip_documentos a
            where a.cod_tip_documento= v_tip_doc_cli/*p_tip_documento*/;
       exception
         when no_data_found then
           v_tip_doc_dna:= null;
         when others then
           v_tip_doc_dna:= null;
       end;

      --Validamos Tipo de Documento
     v_lugar:='Validando tipo de documento DNA';
     if v_tip_doc_dna is null then
          v_respuesta:=52;
          v_error:= 'CAMPO TIPO DE DOCUMENTO';
     elsif nvl(length(trim(v_tip_doc_dna)),0) > 3 then
          v_respuesta:=53;
          v_error:= 'CAMPO TIPO DE DOCUMENTO DEBE TENER LONGITUD MAXIMA 3';
     end if;

      --Se envian tipo de documento RUC (Con digito verificador) /CI /OTR 
     if v_tip_doc_dna <> 'RUC' THEN
        if v_tip_doc_dna <> 'CI' then
           v_tip_doc_dna:='OTR';
        end if;
        --Se ajusta para enviar RUC si es contribuyente
        IF v_tip_doc_dna = 'CI' THEN
          --Solo se ajusta si es contribuyente, sino se envia tal cual
          IF nvl(FUE_OBT_PER_TIP_IVA(v_cod_persona),'NC')= 'CO' then
             v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*p_nro_documento*/);
             v_nro_documento:= v_nro_doc_cli/*p_nro_documento*/||v_dig_verificador;   
             v_tip_doc_dna :='RUC';
          else
             v_nro_documento:=v_nro_doc_cli/*p_nro_documento*/;
          end if;
        ELSE
          --Para otros documentos se envia tal cual
          v_nro_documento:=v_nro_doc_cli/*p_nro_documento*/;        
        END IF;
     elsif  v_tip_doc_dna='RUC' THEN
          v_guion:= instr(v_nro_doc_cli/*p_nro_documento*/,'-');
          if v_guion = 0 then
            --No tiene guion, agregamos el digito verificador al final
            v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli/*p_nro_documento*/);
            v_nro_documento:= v_nro_doc_cli/*p_nro_documento*/||v_dig_verificador;
          else
            --Ya se recibe con guion
            v_parte1:=  substr(v_nro_doc_cli/*p_nro_documento*/,1,v_guion-1);
            v_parte2:=  substr(v_nro_doc_cli/*p_nro_documento*/,v_guion+1,1);
            v_nro_documento:= v_parte1||v_parte2;
          end if;
     END IF;

     v_lugar:='Validando Nro. de documento DNA';
     if v_nro_documento is null then
          v_respuesta:=54;
          v_error:= 'CAMPO NRO DE DOCUMENTO NULO';
     elsif nvl(length(trim(v_nro_documento)),0) > 11 then
          v_respuesta:=55;
          v_error:= 'CAMPO NRO DE DOCUMENTO DEBE TENER LONGITUD MAXIMA 11';
     end if;

     --Validamos Operacion
     v_lugar:='Validamos Observacion';
     if p_observacion is null then
          v_respuesta:=56;
          v_error:= 'CAMPO OBSERVACION NULO';
     elsif nvl(length(trim(p_observacion)),0) > 500 then
          v_respuesta:=57;
          v_error:= 'CAMPO OBSERVACION DEBE TENER LONGITUD MAXIMA 500';
     end if;

  end if;

   v_lugar:= 'llamando al ws de consulta de Boletas de Pago';
 if  to_number(v_respuesta)= 0 then
      v_lugar:= 'Cargando URL JSON';
      v_url := g_dna_webservice || c_ws_metodo;
      v_lugar:= 'Cargando Parametros';
      v_parametros := utl_lms.format_message('accessToken=%s&idOrdenPago=%s&tipoDocumento=%s&nroDocumento=%s&observacion=%s',g_api_gateway, utl_url.escape(p_id_operacion), utl_url.escape(v_tip_doc_dna),utl_url.escape(V_nro_documento),utl_url.escape(p_observacion));
      v_lugar:= 'Enviando env Pos';
      v_resPost := fue_env_post(p_parametros => v_parametros, p_url => v_url);

   IF (v_resPost.error = 'N') THEN
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      v_cod_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'codigoRetorno');
      v_des_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'descripcionRetorno');
      v_resultado:= v_resPost.respuesta;

      if to_number(v_cod_retorno)= 0 then
          --Seteamos output
          v_lugar:= 'Cargando respuestas';
          v_error:= null;
          v_respuesta:= 0;
      elsif v_cod_retorno is null then
          if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
             v_error:= 'ERROR INTERNO...';
             v_respuesta:= 3;
          else
             --Se mejora mensaje de Salida para ITGF
             v_error:= 'Servicio de reversion de DNA con inconvenientes!! Intente mas tarde!!';
             v_respuesta:= 3;
          end if;
      else
          v_error:= v_des_retorno;
          v_respuesta:= v_cod_retorno;
      end if;
   ELSE
      v_lugar:= 'Cargando respuesta por error';
       if substr(upper(v_cod_usuario),1,4) = 'HBAN' then
             v_error:= 'ERROR INTERNO.';
             v_respuesta:= 3;
       else
             --Se mejora mensaje de Salida para ITGF
             v_error:= 'Servicio de reversion de DNA con inconvenientes!! Intente mas tarde!!';
             v_respuesta:= 3;
       end if;  
   END IF;    
       
  END IF;

  v_lugar:= 'Insertando en tabla de reversiones de Boletas de Pago';
  if to_number(v_respuesta)= 0 then
            v_hora:= to_char(sysdate,'hh24:mi:ss');
            insert into   LC_REV_BOL_PAGO(
                              id_operacion,
                              fecha_env,
                              hora_env,
                              tip_documento,
                              nro_documento,
                              estado,
                              mensaje,
                              respuesta,
                              observacion
                              )values(
                              p_id_operacion,
                              v_fec_actual,
                              v_hora,
                              p_tip_documento,
                              p_nro_documento,
                              'R',
                              v_parametros,
                              v_resultado,
                              p_observacion
                              );
                              commit;

      end if;
   p_respuesta:= to_number(v_respuesta);
   p_msj_error:= v_error;
   
else
   p_respuesta:= 0;
   p_msj_error:= null;
end if;
   
EXCEPTION
  when too_many_rows then
    p_respuesta:= -30;
    RAISE_APPLICATION_ERROR( -20000, 'Mas de Una fila Recuperada: '||v_lugar);
  when others then
    p_respuesta:= to_number(v_respuesta);
    RAISE_APPLICATION_ERROR( -20000, 'Error: '||v_lugar||'- '||sqlerrm);

END;

FUNCTION FU_VAL_BANCO(p_cod_banco  IN ge_bancos.cod_banco%TYPE DEFAULT NULL,
                      p_cod_pais   IN ba_paises.cod_pais%TYPE DEFAULT NULL,
                      p_cod_ciudad IN ba_ciudades.cod_ciudad%TYPE DEFAULT NULL) RETURN NUMBER IS
  v_cod_per_banco ge_bancos.cod_persona%TYPE;
  v_cantidad      NUMBER := 0;
  v_cod_ciu_banco ba_ciudades.cod_ciudad%type;
  v_ciu_banco     ba_ciudades.descripcion%type;
  v_cod_pai_banco ba_paises.cod_pais%type;
  v_pai_banco     ba_paises.descripcion%type;
BEGIN
  IF p_cod_banco IS NULL THEN
     RETURN 0;
  END IF;  
  
  begin
     select count(*), a.cod_persona
       into v_cantidad, v_cod_per_banco
       from ge_bancos a
       where a.estado ='A'
         and cod_banco <> 999
         and a.cod_banco = nvl(p_cod_banco, -1)
       group by a.cod_persona;
  exception
     when others then
        v_cantidad := 0;
  end;
  -- si existe banco
  if nvl(v_cantidad,0) = 0 then
     return -9;
  end if;
  --Obtenemos Pais y Ciudad del Banco y validamos con lo ingresado.
  pre_obt_ciu_pais(v_cod_per_banco, v_cod_pai_banco, v_pai_banco, v_cod_ciu_banco, v_ciu_banco);
  -- si el pais del banco es valido
  if nvl(v_cod_pai_banco,-99) <> nvl(p_cod_pais,-99) then
     return -10;
  end if;
  -- si la ciudad del banco es valida
  if nvl(v_cod_ciu_banco,-99) <> nvl(p_cod_ciudad,-99) then
     return -11;
  end if;

  RETURN 0;
END;

FUNCTION FU_VAL_BCO_CORRESPONSAL(p_cod_bco_cor_contra IN ge_bancos.cod_banco%TYPE DEFAULT NULL,
                                 p_cod_pai_bco_contra IN ba_paises.cod_pais%TYPE DEFAULT NULL,
                                 p_cod_ciu_bco_contra IN ba_ciudades.cod_ciudad%TYPE DEFAULT NULL) RETURN NUMBER IS
   v_cod_banco ge_bancos.cod_banco%TYPE;
   v_cantidad NUMBER := 0;
BEGIN
   -- Verificamos el Banco Intermediario(Opcional) , si recibimos null asignamos 999
   v_cod_banco := nvl(p_cod_bco_cor_contra, 999);
  
   begin
      select count(*)
        into v_cantidad
        from ge_bancos a
       where a.estado = 'A'
         and a.ubicacion = 'E'
         and a.cod_banco = v_cod_banco;
   exception
      when others then
         v_cantidad := 0;
   end;
   if v_cantidad = 0 then
      return -8;
   end if;
  
   --Validamos el Pais del Banco Intermediario
   if p_cod_pai_bco_contra is not null then
      begin
         select count(*)
           into v_cantidad
           from ba_paises a
          where a.cod_pais = p_cod_pai_bco_contra;
      exception
         when others then
            v_cantidad := 0;
      end;
      
      if v_cantidad = 0 then
         return -12;
      end if;
   end if;
   
   --Validamos la ciudad del Banco Intermediario
   if p_cod_ciu_bco_contra is not null then
      begin
         select count(*)
           into v_cantidad
           from ba_ciudades a
          where a.cod_ciudad=p_cod_ciu_bco_contra;
      exception
         when others then
            v_cantidad := 0;
      end;
      if v_cantidad = 0 then
         return -13;
      end if;
   end if;
   
   return 0;
END;

end PAL_TRA;
/

