CREATE OR REPLACE PACKAGE BODY IT.PAP_DEV IS
r_deven         pr_devengados%rowtype;
V_SECUENCIA     NUMBER;
V_TOT_INTERES   PR_CUOTAS.MTO_INTERES%TYPE;
V_HORAMOVIM     VARCHAR2(8);
V_MONEDA        VARCHAR2(3);
V_FEC_SIST      DATE;
V_ESTADO        PR_CTA_PRESTAMOS.ESTADO%TYPE;
v_cod_persona   ge_clientes.cod_persona%type;
v_cod_tra_hij   ge_transacciones.cod_transaccion%type;
v_proceso       VARCHAR2(01);
v_redondeo      NUMBER(1);
v_acu_devengado VARCHAR2(1) default 'N';
v_dev_ant_can_par PR_CUOTAS.Dev_Acumulado%type;
L_CAN_ERROR NUMBER :=0;
TYPE typ_cuota IS TABLE OF pr_cuotas%ROWTYPE ; --CIE-605
reg_upd_cuotas typ_cuota := typ_cuota(); --CIE-605

/* Obtiene el valor del parametro */ --CIE-605
FUNCTION LF_OBT_PARDINAMICO
   (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
 ,P_COD_MODULO IN NUMBER DEFAULT NULL
 ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
 ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
 ,P_COD_OFICINA IN NUMBER  DEFAULT NULL
 ,P_COD_SUB_MODALIDAD IN varchar2 DEFAULT NULL
 )
 RETURN VARCHAR2;
 /* Obtiene el capital acumulado. */ --CIE-605
FUNCTION LF_OBT_CAPITAL_ACUMU
 (P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN number;
/* Obtiene la cotizacion de una moneda */ --CIE-605
FUNCTION LF_OBT_COTIZACION
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER;
/* Generar devengado de prestamos por cuotas. */
PROCEDURE PR_PRO_DEV_CUOTAS
 (P_PROCESO IN VARCHAR2
 )
 IS
V_MONE_LOCAL      BA_MONEDAS.COD_MONEDA%TYPE;
   V_MONE_FUERTE     BA_MONEDAS.COD_MONEDA%TYPE;
   V_COTIZACION      GE_COTIZACIONES.VAL_CONVERSION%TYPE;
   V_INTERES         PR_CUOTAS.MTO_INTERES%TYPE;
   V_CAPITAL         PR_CUOTAS.MTO_CAPITAL%TYPE;
   V_TASA            NUMBER;
   V_FEC_INI         DATE;
   V_FEC_FIN         DATE;
   V_FEC_ANT         DATE;
   V_FEC_ULT_DEV     DATE;
   V_NRO_CUENTA      PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE;
   v_categoria       ge_clientes.cat_automatica%type;
   ulthabm           date;
   ultdiam           date;
   v_pri_diam        date;
   v_cotiz_fuerte    ge_cotizaciones.val_venta%type;
   ---
   v_dev_suspenso    pr_cuotas.dev_suspenso%type;
   v_dev_no_cobrado  pr_cuotas.dev_no_cobrado%type;
   v_dev_no_cobrados pr_cuotas.dev_no_cobrado%type;
   v_dev_suspensos   pr_cuotas.dev_suspenso%type;
   v_dev_acumulados  pr_cuotas.dev_acumulado%type;
   v_tot_suspenso    pr_cuotas.dev_suspenso%type;
   v_tot_no_cobrado  pr_cuotas.dev_no_cobrado%type;
   v_mto_ajuste      pr_devengados.mto_ajuste%type;
   v_fec_ini_dev     pr_devengados.fec_inicio%type;
   v_fec_fin_dev     pr_devengados.fec_inicio%type;
   v_devengo         varchar2(1);
   v_no_cobrado      pr_cuotas.dev_no_cobrado%type;
   v_no_cobrado_cuo  pr_cuotas.dev_no_cobrado%type;
   v_suspenso        pr_cuotas.dev_suspenso%type;
   v_suspenso_cuo    pr_cuotas.dev_suspenso%type;
   v_acumulado       pr_cuotas.dev_acumulado%type;
   v_acumulado_cuo   pr_cuotas.dev_acumulado%type;
   v_int_cobrado     pr_cuotas.sal_interes%type;
   v_mto_interes     pr_cuotas.sal_interes%type;
   v_sal_interes     pr_cuotas.sal_interes%type;
   v_int_devengar    pr_cuotas.sal_interes%type;
   v_val_int_devengar pr_cuotas.sal_interes%type;
   v_ult_dev_mes      varchar2(1); 
   v_exi_cta_vision   varchar2(1); -- existe cta vision
   v_redondeo_ml      number(1);
   v_redondeo_mf      number(1);
   v_cod_programa     ba_programas.cod_programa%type;
   --- Definicion del cursor de prestamos vigentes a procesar
   cursor c_prestamos IS
   SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, nro_solicitud,
          a.val_int_devengar, val_tasa, a.fec_inicio, a.fec_vencimiento, a.tipo, a.estado,
          a.sal_interes, a.cod_moneda, fec_ult_devengado fec_ult_dev,
          c.cod_gru_economico, fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
          a.dev_no_cobrado, tip_interes, decode(x.nro_cuenta,null,'N','S') cta_fusion
     FROM ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a, ge_cta_dat_fusion x
    WHERE c.cod_persona = b.cod_persona
      AND b.nro_cuenta  = a.nro_cuenta
      and a.cod_modalidad not in (670,671,699) --- No debe devengarse VENTA DE BIENES ADJUDICADOS
      and b.relacion    = 'P'
      AND a.estado not in ('N','I')  --- No incluir Canceladas ni Irrecuperables
      --- Que no tome cuentas vencidas aunque no halla devengado todo
      and (a.fec_vencimiento > decode(v_fec_sist,v_fec_fin,v_fec_sist,(v_fec_fin - 1))
         or (a.fec_vencimiento > a.fec_ult_devengado and a.val_int_devengar <> 0)) -- Modificado por ICL por diferencia en Utilidad de Agosto/2010
      --- No debe devengar las cuentas canceladas por adelantado
      and nvl(a.fec_ult_devengado,a.fec_inicio-1) < v_fec_fin
      AND a.fec_inicio <= v_fec_sist
      and a.nro_cuenta = x.nro_cuenta(+)
      and a.cod_modulo = x.cod_modulo(+);
  
    TYPE cursor1_type IS TABLE of c_prestamos%rowtype;
    reg cursor1_type;
    
     TYPE t_cuotas IS RECORD (
        nro_cuota         pr_cuotas.nro_cuota%TYPE,
        mto_capital       pr_cuotas.mto_capital%TYPE,
        mto_int_documentado pr_cuotas.mto_int_documentado%TYPE,
        mto_cap_adelantado pr_cuotas.mto_cap_adelantado%TYPE,
        fec_vencimiento   pr_cuotas.fec_vencimiento%TYPE,
        nro_cuenta        pr_cuotas.nro_cuenta%TYPE,
        dev_acumulado     pr_cuotas.dev_acumulado%TYPE,
        mto_interes       pr_cuotas.mto_interes%TYPE,
        mto_int_descontado pr_cuotas.mto_int_descontado%TYPE,
        dev_no_cobrado     pr_cuotas.dev_no_cobrado%TYPE,
        dev_suspenso       pr_cuotas.dev_suspenso%TYPE,
        sal_interes        pr_cuotas.sal_interes%TYPE,
        sal_int_documentado pr_cuotas.sal_int_documentado%TYPE,
        acu_devengado     CHAR(1) -- Para el DECODE
    );
    -- Definir una tabla de ese tipo
    TYPE t_cuotas_tab IS TABLE OF t_cuotas;
    v_cuotas t_cuotas_tab;

BEGIN
   PAG_CAL.PR_OBT_DAT_CALENDAR(6);
   v_fec_sist     := PAG_CAL.G_FEC_ACTUAL;
   v_fec_ant      := PAG_CAL.G_FEC_ANTERIOR;
   ulthabm        := PAG_CAL.G_ULT_DIA_MES_HABIL;
   ultdiam        := PAG_CAL.G_ULT_DIA_MES;
   v_pri_diam     := PAG_CAL.G_PRI_DIA_MES;
   v_mone_local   := PAG_GEN.FU_OBT_MON_LOCAL;
   v_mone_fuerte  := PAG_GEN.FU_OBT_MON_FUERTE;
   v_cotiz_fuerte := LF_OBT_COTIZACION(v_mone_fuerte,v_fec_sist);
   v_proceso      := p_proceso;
   v_ult_dev_mes  := 'N';  
   --redondeo moneda fuerte y local
   v_redondeo_ml := lf_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, v_mone_local, 61);
   v_redondeo_mf := lf_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, v_mone_fuerte, 61);
   -- La primera vez se utiliza para la apertura del cursor, para saber
   --- hasta que fecha debe devengar por si existan devengados adelantados
   IF P_PROCESO = 'I' THEN --- LLAMADO DESDE UN INICIO DE DIA
      --- para devengar sabados,domingos,feriados
      v_fec_fin := v_fec_sist - 1;
   ELSIF P_PROCESO = 'F' THEN --- LLAMADO DESDE UN CIERRE DE DIA
      IF v_fec_sist = ulthabm THEN
         v_fec_fin := ultdiam;
         v_ult_dev_mes := 'S';
      ELSE
         v_fec_fin := v_fec_sist;
      END IF;
      --setear programa para evitar controles de triggers que no ameritan por actualización de devengados
      v_cod_programa := pae_cnf.g_programa;
      pae_cnf.g_programa := 'PRP_DEV_PRE_FIN';
   END IF;
   OPEN c_prestamos;
   LOOP
    FETCH c_prestamos BULK COLLECT INTO reg LIMIT 5000;
    FOR i in 1.. reg.count LOOP
      --- totales por cada prestamo situacion cartera
      v_nro_cuenta    := reg(i).nro_cuenta;
      v_estado        := reg(i).estado;
      v_moneda        := reg(i).cod_moneda;
      v_fec_ult_dev   := reg(i).fec_ult_dev;
      v_devengo       := 'N';
      IF P_PROCESO = 'I' THEN --- LLAMADO DESDE UN INICIO DE DIA
         --- para devengar sabados,domingos,feriados
         v_fec_fin := v_fec_sist - 1;
      ELSIF P_PROCESO = 'F' THEN --- LLAMADO DESDE UN CIERRE DE DIA
         IF v_fec_sist = ulthabm THEN
            v_fec_fin := ultdiam;
            v_ult_dev_mes := 'S';
         ELSE
            v_fec_fin := v_fec_sist;
            v_ult_dev_mes := 'N';
         END IF;
      END IF;
      IF v_moneda != v_mone_local THEN
         if v_moneda = v_mone_fuerte then
            v_cotizacion := v_cotiz_fuerte;
            v_redondeo   := v_redondeo_mf;
         else
            v_cotizacion := LF_OBT_COTIZACION(v_moneda,v_fec_sist);
            v_redondeo   := lf_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg(i).cod_modulo, reg(i).cod_modalidad, v_moneda, reg(i).cod_oficina);
         end if;
      ELSE
         v_redondeo := v_redondeo_ml;
      END IF;
      
      v_categoria := nvl(reg(i).categoria,1);
      IF reg(i).fec_ult_dev  IS NULL THEN
         v_fec_ini := reg(i).fec_inicio;
         v_fec_ult_dev := reg(i).fec_inicio;
      ELSIF reg(i).fec_ult_dev >= reg(i).fec_inicio THEN
         v_fec_ini := reg(i).fec_ult_dev + 1;
      END IF;
      IF v_fec_fin >= reg(i).fec_vencimiento THEN --si ya esta vencido o vence hoy el prestamo,se devenga hasta el vto
         v_fec_fin := reg(i).fec_vencimiento - 1;
      END IF;
      v_tasa := reg(i).val_tasa;
      --- Inicializar variables de calculo
      v_tot_suspenso   := 0;
      v_tot_no_cobrado := 0;
      v_exi_cta_vision := reg(i).cta_fusion; 

      SELECT nro_cuota, mto_capital, mto_int_documentado, mto_cap_adelantado,
          fec_vencimiento, nro_cuenta, dev_acumulado, mto_interes,
          mto_int_descontado,nvl(dev_no_cobrado,0), nvl(dev_suspenso,0), 
          sal_interes, nvl(sal_int_documentado,0),decode(dev_no_cobrado,0,'N','S') acu_devengado
          BULK COLLECT INTO v_cuotas
     FROM pr_cuotas a
    WHERE a.nro_cuenta = reg(i).nro_cuenta
      and a.nro_cuota > 0
      AND a.estado <> 'N'
      and a.sal_interes + nvl(a.sal_int_documentado,0) > 0
      --- Cuando devenga de mas tambien debe incluir
      AND ((nvl(dev_acumulado,0) <> (mto_interes + nvl(mto_int_documentado,0) - nvl(mto_int_descontado,0)))
      --- debe incluir tambien los que devengaron adelantado, para ajustar
       or  (a.fec_vencimiento > v_fec_ult_dev)--)
      --- debe incluir tambien los que tengan diferencia del Dev_no_cobrado/Suspenso
       OR  (nvl(dev_no_cobrado,0)+nvl(dev_suspenso,0)) <> (nvl(dev_acumulado,0)-((mto_interes+nvl(mto_int_documentado,0)-nvl(mto_int_descontado,0))-
           (sal_interes+nvl(sal_int_documentado,0)))) )
    ORDER BY a.nro_cuota;
      
      FOR j IN 1 .. v_cuotas.COUNT LOOP
         v_interes          := 0;
         v_dev_no_cobrado   := 0;
         v_dev_suspenso     := 0;
         v_dev_no_cobrados  := 0;
         v_dev_suspensos    := 0;
         v_dev_acumulados   := 0;
         v_mto_ajuste       := 0;
         v_val_int_devengar := 0;
         v_int_devengar     := 0;
         v_int_cobrado      := 0;
         v_no_cobrado       := 0;
         v_suspenso         := 0;
         v_acumulado        := 0;
         v_mto_interes      := 0;
         v_sal_interes      := 0;
         r_deven            := null;
         v_fec_fin_dev      := v_fec_fin;
         v_acu_devengado    := v_cuotas(j).acu_devengado; -- Variable que indica si se debe acumular el devengado en pr_ins_pr_devengados
         v_dev_ant_can_par  := 0; -- almacena devengado acumulado antes de cancelacion parcial de capital

         if reg(i).tip_interes = 'V' then
            --- Para prestamos vencidos recorrer cuotas cuya fecha de
            --- inicio de devengado ha transcurrido
            v_fec_ini_dev := nvl(FU_OBT_FEC_INI_CUOTA(reg(i).nro_cuenta, v_cuotas(j).nro_cuota),reg(i).fec_inicio);
          
            if v_fec_ini_dev > v_fec_ini then
               exit;
            end if;
         else
            v_fec_ini_dev := reg(i).fec_inicio;
         end if;

         --- Recuperar capital segun el tipo de prestamo
         if reg(i).tip_interes = 'A' then
            v_capital := nvl(v_cuotas(j).mto_capital,0) + nvl(v_cuotas(j).mto_int_documentado,0) - nvl(v_cuotas(j).mto_cap_adelantado,0);
         else
            v_capital := LF_OBT_CAPITAL_ACUMU(v_fec_ini_dev, reg(i).nro_cuenta);
         end if;
         if v_cuotas(j).fec_vencimiento < v_fec_fin_dev + 1 then
            v_fec_fin_dev := v_cuotas(j).fec_vencimiento - 1; --- Hasta el vencimiento de la cuota
         end if;

         -- Recupera dev anterior acancelacion parcial en caso que exista para la cuota
         -- si hay mas de un registro para la cuota se toma el ultimo, el de mayor fecha, que no este reversado
         begin
            select a.dev_acumulado, a.fecha
                   into v_dev_ant_can_par, v_fec_ini_dev
            from PR_COB_AMO_PARCIAL a
            where a.nro_cuenta = v_nro_cuenta
            and a.nro_cuota = v_cuotas(j).nro_cuota
            and a.reversado='N'
            and a.fec_insercion = (select max(fec_insercion)
                                   from pr_cob_amo_parcial b
                                   where b.nro_cuenta = a.nro_cuenta
                                    and b.nro_cuota = a.nro_cuota
                                    and b.reversado = 'N');


          EXCEPTION
              WHEN OTHERS THEN
                v_dev_ant_can_par := 0;
          end;

         --- Calcular Interes devengado desde la fecha de inicio de devengado de la cuota
         v_interes := FU_CAL_INTERES(v_fec_ini_dev, v_fec_fin_dev, v_capital,
                                             reg(i).nro_solicitud, v_tasa,
                                             v_cuotas(j).nro_cuenta, v_cuotas(j).nro_cuota );
                                             --- Se agregó nro de cuenta y cuota para calculo de tasas variables

         v_interes := round(v_interes, v_redondeo);
         --- Calcular el devengado por diferencia del acumulado a la fecha de fin
         --- /*dydmr 2003 fm 09/07/2015 */SC 12793 / EP 2015-06 - N.AN. suma el dev acumulado anterior a cancelacion parcial para evitar dar devengado negativo
         v_interes := nvl(v_interes,0) - nvl(v_cuotas(j).dev_acumulado,0) + nvl(v_dev_ant_can_par,0);
         --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
         if v_cuotas(j).fec_vencimiento = v_fec_fin_dev + 1 then
            if nvl(v_interes,0) + nvl(v_cuotas(j).dev_acumulado,0) <>
               nvl(v_cuotas(j).mto_interes,0) + nvl(v_cuotas(j).mto_int_documentado,0)- nvl(v_cuotas(j).mto_int_descontado,0) then
               v_mto_ajuste := v_interes - (nvl(v_cuotas(j).mto_interes,0) + nvl(v_cuotas(j).mto_int_documentado,0)- nvl(v_cuotas(j).mto_int_descontado,0) - nvl(v_cuotas(j).dev_acumulado,0));
               v_interes    := (nvl(v_cuotas(j).mto_interes,0) + nvl(v_cuotas(j).mto_int_documentado,0)- nvl(v_cuotas(j).mto_int_descontado,0) - nvl(v_cuotas(j).dev_acumulado,0));
            end if;
         end if;

         --- Verificar que no quede en negativo el val_int_devengar
         --- Incluye en calculos el dev acumulado anterior a cancelacion parcial
         if (nvl(v_cuotas(j).mto_interes,0) + nvl(v_cuotas(j).mto_int_documentado,0) - nvl(v_cuotas(j).mto_int_descontado,0))
            < (nvl(v_cuotas(j).dev_acumulado,0) + nvl(v_interes,0) - nvl(v_dev_ant_can_par,0)) then
            v_mto_ajuste := v_interes;
            v_interes :=  (nvl(v_cuotas(j).mto_interes,0) + nvl(v_cuotas(j).mto_int_documentado,0) - nvl(v_cuotas(j).mto_int_descontado,0))
                          - nvl(v_cuotas(j).dev_acumulado,0) + nvl(v_dev_ant_can_par,0);
            v_mto_ajuste := v_mto_ajuste - v_interes;
         end if;

         --- Verificar si debe actualizar el suspenso o no cobrado
         IF v_estado IN ('A','C') AND v_categoria IN (1,2) and v_exi_cta_vision = 'N' THEN /* solo los est 'A' y 'C' y categ 1 y 2 y que bno sean las cuentas MT de vision fusion*/
            v_dev_no_cobrado := v_interes;
            v_tot_no_cobrado := v_tot_no_cobrado + v_dev_no_cobrado;
            r_deven.tipo     := 'N';
         else
            v_dev_suspenso   := v_interes;
            v_tot_suspenso   := v_tot_suspenso + v_dev_suspenso;
            r_deven.tipo     := 'S';
         end if;
   
         v_dev_no_cobrados :=  nvl(v_cuotas(j).dev_no_cobrado,0) + nvl(v_dev_no_cobrado,0);
         v_dev_suspensos := nvl(v_cuotas(j).dev_suspenso,0) + nvl(v_dev_suspenso,0);
         v_dev_acumulados := nvl(v_cuotas(j).dev_acumulado,0)  + nvl(v_dev_no_cobrado,0) + nvl(v_dev_suspenso,0);
         v_no_cobrado := nvl(v_dev_no_cobrados,0) + nvl(v_dev_suspensos,0);
         v_acumulado :=  nvl(v_dev_acumulados,0); 
         v_int_cobrado := (v_cuotas(j).mto_interes+nvl(v_cuotas(j).mto_int_documentado,0)-v_cuotas(j).mto_int_descontado)-(v_cuotas(j).sal_interes+nvl(v_cuotas(j).sal_int_documentado,0));
        
         If  v_no_cobrado <> (v_acumulado-v_int_cobrado) or v_no_cobrado < 0 then
            If v_estado IN ('A','C') AND v_categoria IN (1,2) and v_exi_cta_vision = 'N' THEN
               v_dev_suspensos := 0;
               if v_int_cobrado > v_acumulado then
                 v_dev_no_cobrados := 0;
               else
                 v_dev_no_cobrados := v_acumulado-v_int_cobrado;
               end if;
            else
               if v_int_cobrado > v_acumulado then
                  v_dev_suspensos := 0;
               else
                 v_dev_suspensos := v_acumulado-v_int_cobrado;
               end if;
               v_dev_no_cobrados := 0;
            end if;   
         End if;
         --Cargar los valores de las variables en la colección
        BEGIN
          reg_upd_cuotas.extend;
          reg_upd_cuotas(reg_upd_cuotas.count).dev_no_cobrado := v_dev_no_cobrados;
          reg_upd_cuotas(reg_upd_cuotas.count).dev_suspenso := v_dev_suspensos;
          reg_upd_cuotas(reg_upd_cuotas.count).dev_acumulado := v_dev_acumulados;
          reg_upd_cuotas(reg_upd_cuotas.count).nro_cuota:= v_cuotas(j).nro_cuota;
          reg_upd_cuotas(reg_upd_cuotas.count).nro_cuenta := reg(i).nro_cuenta;
        END;                       
         --- Insertar devengados
         r_deven.nro_cuenta        := v_nro_cuenta;
         r_deven.nro_cuota         := v_cuotas(j).nro_cuota;
         r_deven.fecha             := v_fec_sist;
         r_deven.fec_inicio        := v_fec_ini_dev;
         r_deven.fec_ult_devengado := v_fec_fin_dev;
         r_deven.cod_moneda        := reg(i).cod_moneda;
         r_deven.estado            := reg(i).estado;
         r_deven.categoria         := nvl(reg(i).categoria,1);
         r_deven.capital           := v_capital;
         r_deven.val_tasa          := reg(i).val_tasa;
         r_deven.can_dia_interes   := v_fec_fin_dev - v_fec_ini + 1;
         r_deven.mto_dev_actual    := v_interes;
         r_deven.mto_ajuste        := v_mto_ajuste;
         r_deven.mto_dev_acumulado := v_interes;
         --- Para casos en que no exista el registro y sea la primera vez
         r_deven.mto_dev_anterior  := v_cuotas(j).dev_acumulado - nvl(v_dev_ant_can_par,0);
  
         --- Actualizar el registro existente, de no existir, insertar
         if r_deven.fecha = V_FEC_ANT + 1
          or (nvl(v_proceso,'F') = 'I' and r_deven.fecha <> V_FEC_ANT + 1)
          or (to_char(r_deven.fecha,'YYYYMM') <> to_char(V_FEC_ANT,'YYYYMM') and r_deven.fecha = v_pri_diam) then
            --- No corresponde a fin de semana o feriado
            --- O es el inicio del la mañana del primer dia habil siguiente de fin de semana o feriados
            --- O hubo un fin de mes en el medio y se esta procesando el primer dia del mes siguiente
            merge into pr_devengados p
            using (select r_deven.nro_cuenta nro_cuenta, r_deven.nro_cuota nro_cuota, r_deven.tipo tipo, r_deven.cod_moneda cod_moneda, r_deven.estado estado,
                          r_deven.categoria categoria, r_deven.capital capital, r_deven.val_tasa val_tasa from dual) a
            on (p.nro_cuenta    = a.nro_cuenta
               and p.nro_cuota  = a.nro_cuota
               and p.tipo       = a.tipo
               and p.cod_moneda = a.cod_moneda
               and p.estado     = a.estado
               and p.categoria  = a.categoria
               and p.capital    = a.capital
               and p.val_tasa   = a.val_tasa)
            when matched then   
              update set p.can_dia_anterior  = nvl(can_dia_interes,0),
                         p.mto_dev_anterior  = mto_dev_actual,
                         p.can_dia_interes   = r_deven.fec_ult_devengado - fec_inicio +1,
                         p.mto_dev_actual    = decode(fecha, r_deven.fecha, mto_dev_actual, 0) + nvl(r_deven.mto_dev_actual,0),
                         p.mto_ajuste        = nvl(r_deven.mto_ajuste,0),
                         p.mto_dev_acumulado = mto_dev_acumulado + nvl(r_deven.mto_dev_actual,0),
                         p.fecha             = r_deven.fecha,
                         p.fec_ult_devengado = r_deven.fec_ult_devengado
             when not matched then
              insert 
                  (nro_cuenta, nro_cuota, tipo, fecha, fec_inicio, fec_ult_devengado, 
                   cod_moneda, estado, categoria, capital, val_tasa, can_dia_interes, 
                   mto_dev_anterior, can_dia_anterior, mto_dev_actual, mto_ajuste, 
                   mto_dev_acumulado)
              values
                  (r_deven.nro_cuenta, r_deven.nro_cuota, r_deven.tipo, r_deven.fecha, r_deven.fec_inicio, r_deven.fec_ult_devengado, 
                   r_deven.cod_moneda, r_deven.estado, r_deven.categoria, r_deven.capital, r_deven.val_tasa, r_deven.can_dia_interes, 
                   nvl(r_deven.mto_dev_anterior,0), r_deven.can_dia_anterior, r_deven.mto_dev_actual, r_deven.mto_ajuste,
                   nvl(r_deven.mto_dev_anterior,0)+nvl(r_deven.mto_dev_acumulado,0));

         else
            --- Existió un feriado o fin de semana y debe acumular para asentar todo el dia habil en el cierre
            merge into pr_devengados p
            using (select r_deven.nro_cuenta nro_cuenta, r_deven.nro_cuota nro_cuota, r_deven.tipo tipo, r_deven.cod_moneda cod_moneda, r_deven.estado estado,
                          r_deven.categoria categoria, r_deven.capital capital, r_deven.val_tasa val_tasa from dual) a
            on (p.nro_cuenta    = a.nro_cuenta
               and p.nro_cuota  = a.nro_cuota
               and p.tipo       = a.tipo
               and p.cod_moneda = a.cod_moneda
               and p.estado     = a.estado
               and p.categoria  = a.categoria
               and p.capital    = a.capital
               and p.val_tasa   = a.val_tasa)
            when matched then   
              update set p.can_dia_anterior  = nvl(can_dia_interes,0), --solo la diferencia entre lo ya devengado y lo q está devengando ahora
                         p.mto_dev_anterior  = mto_dev_actual,
                         p.can_dia_interes   = r_deven.fec_ult_devengado - fec_inicio +1,
                         p.mto_dev_actual    = decode(tipo,'N',decode(v_acu_devengado, 'N', 0, mto_dev_actual),mto_dev_actual) + nvl(r_deven.mto_dev_actual,0), -- RABP-CNF-02-01-2015: DYDMR-1472  (27-10-2014: CNFPCI-52(JIRA))
                         p.mto_ajuste        = nvl(mto_ajuste,0) + nvl(r_deven.mto_ajuste,0),
                         p.mto_dev_acumulado = mto_dev_acumulado + nvl(r_deven.mto_dev_actual,0),
                         p.fecha             = r_deven.fecha,
                         p.fec_ult_devengado = r_deven.fec_ult_devengado
             when not matched then
              insert 
                  (nro_cuenta, nro_cuota, tipo, fecha, fec_inicio, fec_ult_devengado, 
                   cod_moneda, estado, categoria, capital, val_tasa, can_dia_interes, 
                   mto_dev_anterior, can_dia_anterior, mto_dev_actual, mto_ajuste, 
                   mto_dev_acumulado)
              values
                  (r_deven.nro_cuenta, r_deven.nro_cuota, r_deven.tipo, r_deven.fecha, r_deven.fec_inicio, r_deven.fec_ult_devengado, 
                   r_deven.cod_moneda, r_deven.estado, r_deven.categoria, r_deven.capital, r_deven.val_tasa, r_deven.can_dia_interes, 
                   nvl(r_deven.mto_dev_anterior,0), r_deven.can_dia_anterior, r_deven.mto_dev_actual, r_deven.mto_ajuste,
                   nvl(r_deven.mto_dev_anterior,0)+nvl(r_deven.mto_dev_acumulado,0));
         end if;
      
         v_devengo := 'S';   
         IF v_ult_dev_mes = 'S' THEN
            -- Si es ultimo devengado de mes se ajusta fec_ini para incluir ctas que inician devengado
            IF v_fec_fin > v_fec_fin_dev THEN
               v_fec_ini := v_fec_fin_dev + 1;
            END IF;
         END IF;
      END LOOP;
  --Actualizar cuotas
  BEGIN
   FORALL i IN 1 .. reg_upd_cuotas.COUNT
      UPDATE PR_CUOTAS
        SET dev_no_cobrado = reg_upd_cuotas(i).dev_no_cobrado,
            dev_suspenso = reg_upd_cuotas(i).dev_suspenso,
            dev_acumulado = reg_upd_cuotas(i).dev_acumulado
        WHERE NRO_CUENTA = reg_upd_cuotas(i).nro_cuenta
          AND NRO_CUOTA = reg_upd_cuotas(i).nro_cuota;      
  EXCEPTION
  WHEN OTHERS THEN
    l_can_error := SQL%BULK_EXCEPTIONS.count;
    IF l_can_error > 0 then
      FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        PRG_ACT_LOG_PROCESOS('PAP
        _DEV.PR_PRO_DEV_CUOTAS',1,trunc(sysdate),to_char(sysdate, 'hh24:mi:ss'),to_char(sysdate, 'hh24:mi:ss'),
                             'Error en UPDATE PR_CUOTAS en Cta: ' || reg_upd_cuotas(indx).nro_cuenta || ' ' ||
                             SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE));
        raise_application_error(-20002, 'Error EN UPDATE PR_CUOTAS en Cta: ' || reg_upd_cuotas(indx).nro_cuenta || ' ' ||
                                SQLERRM(-1 * SQL%BULK_EXCEPTIONS(indx).ERROR_CODE) || ' ');
      END LOOP;
    END IF;
  END;
    --Limpiar variables
    BEGIN 
      reg_upd_cuotas.delete;
    END;  
 
      --- Actualizar maestro de prestamos
      If v_devengo = 'S' then
         -- Solo debe actualizar el maestro si es que devengo.
          update pr_cta_prestamos
             set val_int_devengar  = nvl(val_int_devengar,0) - (nvl(v_tot_suspenso,0) + nvl(v_tot_no_cobrado,0)),
                 dev_acumulado     = nvl(dev_acumulado,0)    + (nvl(v_tot_suspenso,0) + nvl(v_tot_no_cobrado,0)),
                 dev_suspenso      = nvl(dev_suspenso,0)     +  nvl(v_tot_suspenso,0),
                 dev_no_cobrado    = nvl(dev_no_cobrado,0)   +  nvl(v_tot_no_cobrado,0),
                 fec_ult_devengado = v_fec_fin
           where nro_cuenta = reg(i).nro_cuenta;
          --Verificar si los datos de devengado quedaron consistentes, si no corregir
          Select nvl(p.dev_no_cobrado,0), nvl(p.dev_suspenso,0), nvl(p.dev_acumulado,0),
                 nvl(p.val_int_devengar,0),
                   sum(nvl(c.dev_no_cobrado,0)), sum(nvl(c.dev_suspenso,0)),
                   sum(nvl(c.dev_acumulado,0)),
                   sum((nvl(c.mto_interes,0)+nvl(c.mto_int_documentado,0)-nvl(c.mto_int_descontado,0))),
                   sum((nvl(c.sal_interes,0)+nvl(c.sal_int_documentado,0)))
           into v_no_cobrado, v_suspenso, v_acumulado,
                v_val_int_devengar,
                v_no_cobrado_cuo, v_suspenso_cuo,
                v_acumulado_cuo,
                v_mto_interes,v_sal_interes
           from pr_cuotas c, pr_cta_prestamos p
          where p.nro_cuenta = reg(i).nro_cuenta
            and c.nro_cuenta = p.nro_cuenta
            and nro_cuota > 0
          group by p.dev_no_cobrado,p.dev_suspenso,p.dev_acumulado,p.val_int_devengar;
          --
          --Se controla los valores de la cabecera contra la suma de los detalles a fin de no dejar inconsistencias
            v_int_cobrado := nvl(v_mto_interes,0)-nvl(v_sal_interes,0);
            v_int_devengar := v_mto_interes - v_acumulado_cuo;

            If  v_no_cobrado <> v_no_cobrado_cuo
            or  v_suspenso   <> v_suspenso_cuo
            or  v_acumulado  <> v_acumulado_cuo
            or  v_val_int_devengar <> v_int_devengar
            or  v_no_cobrado < 0
            or  v_suspenso   < 0 then
              update pr_cta_prestamos
                 set val_int_devengar  = v_int_devengar,
                     dev_suspenso      = v_suspenso_cuo,
                     dev_no_cobrado    = v_no_cobrado_cuo,
                     dev_acumulado     = v_acumulado_cuo
              where nro_cuenta = reg(i).nro_cuenta;
          End if;
      End if;

     END LOOP;
     EXIT WHEN c_prestamos%NOTFOUND;
   END LOOP;
   close c_prestamos;
   --volver a setear el programa
   pae_cnf.g_programa := v_cod_programa;
EXCEPTION
   WHEN OTHERS THEN
      pae_cnf.g_programa := v_cod_programa;
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,'Cuenta : '||v_nro_cuenta||' - '||SQLERRM);
      end if;
END;
/* Generar devengado de prestamos por cuotas. RE4 */
PROCEDURE PR_PRO_DEV_CUOTAS_RES4
 (P_PROCESO IN VARCHAR2
 )
 IS
/*Solo para dev. paralelo RE4, acumula el devengado y re-calcula por dia*/
   V_MONE_LOCAL      BA_MONEDAS.COD_MONEDA%TYPE;
   V_MONE_FUERTE     BA_MONEDAS.COD_MONEDA%TYPE;
   V_COTIZACION      GE_COTIZACIONES.VAL_CONVERSION%TYPE;
   V_NRO_CUENTA      PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE;
   v_nro_orden       GE_DEV_RES4.nro_orden%type;
   v_cotiz_fuerte    ge_cotizaciones.val_venta%type;
   ---
   v_devengo         varchar2(1);
   --
   v_dias_dev        number(3);
   v_mto_devengado   number(18,2);
   v_fec_proceso     date;
   v_fec_sig_dev     date;
   v_fec_ult_dev     date;
   v_fec_ant_dev     date;
   v_diferencia      number(3);
   --
   v_fec_inicio_det  date;
   v_fec_final_det  date;
   v_mto_dev_actual_det  number(18,2);
   v_can_dia_devengado_det number(4);
   v_mto_dev_diario_det  number(18,2);
   v_nro_cuota    number(4);
   v_nro_cuo_sig    number(4);
   v_tot_dia        number(8);
   v_tot_interes    number(18,2);
   v_mto_acumulado  number(18,2);
   v_mto_dev_act    number(18,2);
   v_can_dia_dev_actual    number(6);
   v_dia_devengar       number(4);
   v_dia_devengado       number(4);
   v_mto_dev_act_ant    number(18,2);
   v_can_dia_dev_act_ant    number(6);
   v_can_dia_dev_act     number(6);
   v_can_dia_acumulado  number(6);
   v_ult_proceso        varchar2(1);
   v_vence              varchar2(1):='N';
   --- Definicion del cursor a procesar
   cursor c_cabecera IS
   SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
          a.fec_dev_inicio fec_inicio,
          a.fec_dev_fin fec_vencimiento,
          cod_moneda,
          a.fec_ult_devengado ,
          a.nro_orden
     FROM GE_DEV_RES4 a
    WHERE a.devengar='S';

    TYPE cursor1_type IS TABLE of c_cabecera%rowtype;
    reg cursor1_type;


---Act.Tabla de Inventario
CURSOR c_act_inventario IS
 select a.nro_cuenta nro_cuenta,
        a.nro_secuencia as clave,
        'E1' as Tabla
   from pr_cta_pre_can_res4 a
    where a.nro_cta_nueva is not null
    and NVL(a.inventariar,'N')='S'
    and nvl(a.reversado,'N')='N'
    and (a.sal_inv_interes=0 and a.sal_inv_int_moratorio=0 and
             a.sal_inv_int_punitorio=0 and a.sal_inv_ges_cobranza=0 and a.sal_inv_sobregiro=0
             and a.sal_inv_val_suspenso=0)
union all
   select a.nro_cuenta nro_cuenta,
        a.nro_sol_nueva as clave,
        'E2' as Tabla
   from PR_CTA_PRE_REF_RES4 a
    where a.nro_cta_nueva is not null
    and NVL(a.inventariar,'N')='S'
    and (a.sal_inv_interes=0 and a.sal_inv_int_moratorio=0 and
             a.sal_inv_int_punitorio=0 and a.sal_inv_ges_cobranza=0 and a.sal_inv_sobregiro=0
             and a.sal_inv_val_suspenso=0)
     order by 1,2;



BEGIN
   PAG_CAL.PR_OBT_DAT_CALENDAR(6);
   v_fec_sist     := PAG_CAL.G_FEC_ACTUAL;
   v_mone_local   := PAG_GEN.FU_OBT_MON_LOCAL;
   v_mone_fuerte  := PAG_GEN.FU_OBT_MON_FUERTE;
   v_cotiz_fuerte := PAG_GEN.FU_OBT_COTIZACION(v_mone_fuerte,v_fec_sist);
   v_fec_sig_dev  := PAG_CAL.G_FEC_PROXIMA;
   v_fec_ant_dev  := PAG_CAL.G_FEC_ANTERIOR;
   v_proceso      := p_proceso;
   V_FEC_ULT_DEV  := null;
   v_fec_proceso  := null;
   v_diferencia   := 0;
   v_devengo:='S';
   v_ult_proceso:= null;
   if upper(p_proceso) ='I' then
       --Buscamos si pasó mas de un día
       v_diferencia:= trunc(v_fec_sist) - trunc(v_fec_ant_dev);
       --Solo si hay un feriado de por medio o un finde se procesa
       if v_diferencia > 1 then
           --Siempre se procesa al día actual
           v_fec_proceso:= v_fec_sist;
           --La Fecha de último devengado es el día actual
           v_fec_ult_dev := v_fec_sist;
        else
          v_devengo:='N';
       end if;
    else
        --Siempre se procesa la siguiente día habil
        v_fec_proceso:= v_fec_sist + 1;
        --La Fecha de último devengado es el día actual
        v_fec_ult_dev := v_fec_sist;
     end if;
if  v_devengo='S' then
 OPEN c_cabecera;
   LOOP
    FETCH c_cabecera BULK COLLECT INTO reg LIMIT 3000;
    FOR i in 1.. reg.count LOOP
        v_fec_inicio_det:=null;
        v_fec_final_det:=null;
        v_mto_dev_actual_det:=null;
        v_can_dia_devengado_det:=null;
        v_mto_dev_diario_det:=null;
        v_nro_cuota :=null;
        v_nro_cuenta    := reg(i).nro_cuenta;
        v_nro_orden     := reg(i).nro_orden;
        v_moneda        := reg(i).cod_moneda;
        v_nro_cuo_sig   := 0;
        v_tot_dia       := 0;
        v_tot_interes   :=0;
        v_mto_acumulado:= 0;
      IF v_moneda != v_mone_local THEN
         if v_moneda = v_mone_fuerte then
            v_cotizacion := v_cotiz_fuerte;
         else
            v_cotizacion := PAG_GEN.FU_OBT_COTIZACION(v_moneda,v_fec_sist);
         end if;
      END IF;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_moneda, reg(i).cod_oficina);
      v_mto_dev_act:=0;
      v_can_dia_dev_actual:=0;
      v_dia_devengar:=0;
      v_dia_devengado:=0;
      v_mto_dev_act_ant:=0;
      v_can_dia_dev_act_ant:=0;
      v_can_dia_dev_act:=0;
      v_can_dia_acumulado:=0;
      v_vence:='N';
      /***** Procesamiento de cuota actual - Estado 'DE' ******/
       SELECT a.fec_inicio,
              a.FEC_FINAL,
              a.MTO_DEV_ACUMULADO,
              a.CAN_DIA_ACUMULADO,
              a.NRO_CUOTA,
              a.mto_interes,
              a.tot_dias,
              a.mto_dev_actual,
              a.can_dia_dev_actual,
              a.ult_proceso
       into   v_fec_inicio_det,
              v_fec_final_det,
              v_mto_dev_actual_det,
              v_can_dia_devengado_det,
              v_nro_cuota,
              v_tot_interes,
              v_tot_dia,
              v_mto_dev_act_ant,
              v_can_dia_dev_act_ant,
              v_ult_proceso
          FROM GE_DEV_RES4_DET a
        WHERE a.nro_cuenta = v_nro_cuenta
          and a.nro_orden= v_nro_orden
          and a.estado = 'DE'; --Finalizados No

            v_dias_dev:=0;
            v_mto_devengado:=0;
            --Si la Fecha de sistema es menor a la fecha de siguiente día hábil
            if v_fec_proceso < v_fec_final_det  then
               v_dias_dev:= v_fec_proceso - v_fec_inicio_det;
               --Volvemos a calcular, para que salga similar a ITGF
                v_mto_dev_diario_det:= v_tot_interes/ v_tot_dia;
                v_mto_devengado:= round(v_mto_dev_diario_det * v_dias_dev,v_redondeo);
                --Actualizamos saldo de mto_dev_actual y can_dia_dev_actual
                --Si es fin de día se le suma uno y un dia de monto
                IF P_PROCESO = 'F' then
                   if v_ult_proceso = 'F' THEN
                      v_mto_dev_act_ant:=0;
                      v_can_dia_dev_act_ant:=0;
                   END IF;
                    v_mto_dev_act:= v_mto_dev_act_ant + round(v_mto_dev_diario_det,v_redondeo);
                    v_can_dia_dev_act:=v_can_dia_dev_act_ant + 1;
                    v_ult_proceso:='F';

                elsif P_PROCESO = 'I' THEN
                  v_can_dia_dev_act_ant:=0;
                  v_mto_dev_act_ant:=0;
                   --Para Dias
                   v_can_dia_acumulado:= v_fec_sist - v_fec_inicio_det;
                   v_dia_devengado:= v_fec_ant_dev - v_fec_inicio_det;
                   v_can_dia_dev_act:=(v_can_dia_acumulado - v_dia_devengado)-1;
                   if v_can_dia_dev_act= 0 then
                       v_can_dia_dev_act:= 1;
                   end if;
                   v_mto_dev_act:= v_can_dia_dev_act * round(v_mto_dev_diario_det,v_redondeo);
                   v_ult_proceso:='I';
                end if;

                update GE_DEV_RES4_DET x
                set x.mto_dev_acumulado= v_mto_devengado,
                    x.can_dia_acumulado= v_dias_dev,
                    x.mto_dev_actual= v_mto_dev_act,
                    x.can_dia_dev_actual= v_can_dia_dev_act,
                    x.ult_proceso=v_ult_proceso
                where x.nro_cuenta= v_nro_cuenta
                  and x.nro_orden= v_nro_orden
                  and x.nro_cuota= v_nro_cuota;
               --Obtenemos el acumulado antes del actual si tiene
               select NVL(sum(d.mto_dev_acumulado),0)
                into v_mto_acumulado
                 from GE_DEV_RES4_DET d
                  where d.nro_cuenta= v_nro_cuenta
                   and d.nro_orden=v_nro_orden
                   and d.nro_cuota <> v_nro_cuota
                   and d.estado='FI';
               v_mto_acumulado:= NVL(v_mto_acumulado,0) + v_mto_devengado;
               --Actualizamos Cabecera
               update GE_DEV_RES4 z
                set z.fec_ult_devengado = V_FEC_ULT_DEV,
                    z.mto_dev_acumulado=v_mto_acumulado,
                    z.mto_dev_actual= v_mto_dev_act
                where z.nro_cuenta= v_nro_cuenta
                  and z.nro_orden= v_nro_orden;
                --Si ya venció al siguiente Día Hábil o vence mañana
           elsif v_fec_proceso >= v_fec_final_det  then
                 --Devengamos hasta la Fecha de Final
                 v_dias_dev:= v_fec_final_det - v_fec_inicio_det;
                 v_mto_dev_diario_det:= v_tot_interes/ v_tot_dia;
                 v_mto_devengado:= round(v_mto_dev_diario_det* v_dias_dev,v_redondeo);
                 --Actualizamos saldo de mto_dev_actual y can_dia_dev_actual
                  --Si es fin de día se le suma uno y un dia de monto
                  IF P_PROCESO = 'F' then
                      if v_ult_proceso = 'F' THEN
                        v_mto_dev_act_ant:=0;
                        v_can_dia_dev_act_ant:=0;
                     END IF;
                     v_mto_dev_act:= v_mto_dev_act_ant + round(v_mto_dev_diario_det,v_redondeo);
                     v_can_dia_dev_act:=v_can_dia_dev_act_ant +1;
                     v_ult_proceso:='F';
                  elsif P_PROCESO = 'I' then
                     v_mto_dev_act_ant:=0;
                     v_can_dia_dev_act_ant:=0;
                     --Para Dias
                     v_can_dia_acumulado:= v_fec_sist - v_fec_inicio_det;
                     v_dia_devengado:= v_fec_ant_dev - v_fec_inicio_det;
                     v_can_dia_dev_act:=(v_can_dia_acumulado - v_dia_devengado)-1;
                     if v_can_dia_dev_act= 0 then
                         v_can_dia_dev_act:= 1;
                     end if;
                     v_mto_dev_act:= v_can_dia_dev_act * round(v_mto_dev_diario_det,v_redondeo);
                     v_ult_proceso:='I';
                  end if;

                 update GE_DEV_RES4_DET x
                  set x.mto_dev_acumulado= v_mto_devengado,
                      x.can_dia_acumulado= v_dias_dev,
                      x.mto_dev_actual= v_mto_dev_act,
                      x.can_dia_dev_actual= v_can_dia_dev_act,
                      x.estado='FI',
                      X.ULT_PROCESO=v_ult_proceso
                  where x.nro_cuenta= v_nro_cuenta
                    and x.nro_orden= v_nro_orden
                    and x.nro_cuota= v_nro_cuota;
                   --Obtenemos el acumulado antes del actual si tiene
                   select NVL(sum(d.mto_dev_acumulado),0)
                    into v_mto_acumulado
                     from GE_DEV_RES4_DET d
                      where d.nro_cuenta= v_nro_cuenta
                       and d.nro_orden=v_nro_orden
                       and d.nro_cuota <> v_nro_cuota
                       and d.estado='FI';
                   v_mto_acumulado:= NVL(v_mto_acumulado,0) + v_mto_devengado;

                 --Actualizamos Cabecera
                 update GE_DEV_RES4 z
                  set  z.fec_ult_devengado = V_FEC_ULT_DEV,
                       z.mto_dev_acumulado=v_mto_acumulado,
                       z.mto_dev_actual= v_mto_dev_act
                 where z.nro_cuenta= v_nro_cuenta
                    and z.nro_orden= v_nro_orden;
                   --Buscamos si hay Siguiente
                  begin
                    select x.nro_cuota
                     into v_nro_cuo_sig
                    from GE_DEV_RES4_DET x
                     where x.nro_cuenta= v_nro_cuenta
                      and x.nro_orden= v_nro_orden
                      and x.nro_cuota= v_nro_cuota +1;
                  exception
                   when no_data_found then
                     v_nro_cuo_sig:= 0;
                   end;

                   if v_nro_cuo_sig > 0 then
                      --Verificamos si los dias son mayores a 1
                      v_vence:='N';
                      IF trunc(v_fec_proceso) = trunc(v_fec_final_det) OR 
                         (trunc(v_fec_final_det) > trunc(v_fec_ant_dev)
                         and trunc(v_fec_final_det) < trunc(v_fec_proceso)) THEN
                         v_vence:='S';
                      END IF;
                      if nvl(v_dia_devengado,0) > 1 
                        and P_PROCESO = 'I'  
                        and v_vence='S' then
                          update GE_DEV_RES4_DET x
                              set x.estado='DE',
                                  x.ult_proceso=v_ult_proceso,
                                  x.mto_dev_actual= v_mto_dev_act
                               where x.nro_cuenta= v_nro_cuenta
                                and x.nro_orden= v_nro_orden
                                and x.nro_cuota= v_nro_cuo_sig;
                                v_devengo := 'S';
                      
                      else
                      
                          update GE_DEV_RES4_DET x
                              set x.estado='DE',
                                  x.ult_proceso=v_ult_proceso
                               where x.nro_cuenta= v_nro_cuenta
                                and x.nro_orden= v_nro_orden
                                and x.nro_cuota= v_nro_cuo_sig;
                                v_devengo := 'S';
                      end if;
                   else
                     --Ya ni hay  nada que devengar
                      update GE_DEV_RES4
                        set fec_ult_devengado = V_FEC_ULT_DEV,
                            devengar='N'
                          where nro_cuenta = v_nro_cuenta
                                and nro_orden = v_nro_orden;
                    end if;

              end if;

     END LOOP;
     EXIT WHEN c_cabecera%NOTFOUND;
   END LOOP;
end if;
   --Actualizamos si se va a inventariar o no
   --Tabla Espejo 1 y 2
   FOR w IN c_act_inventario LOOP
     if w.tabla='E1' then
         update pr_cta_pre_can_res4 b
           set b.inventariar='N'
            where b.nro_cuenta= w.nro_cuenta
              and b.Nro_Secuencia= w.clave;
     elsif w.tabla='E2' then
          update pr_cta_pre_ref_res4 b
           set b.inventariar='N'
            where b.nro_cuenta= w.nro_cuenta
              and b.nro_sol_nueva= w.clave;
     end if;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,'Cuenta Dev Par: '||v_nro_cuenta||' - '||SQLERRM);
      end if;
END;
FUNCTION FU_OBT_VTO_SIN_PAGO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN DATE
 IS

v_vto date;
BEGIN
    SELECT min(fec_vencimiento)
      INTO v_vto
      FROM pr_cuotas
     WHERE estado <> 'N'
       AND nro_cuota > 0
       and nro_cuenta = p_nro_cuenta;
   RETURN v_vto;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR (-20021,SQLERRM||'Al obtener fecha vto. PR_CUOTAS - Prestamo '||p_nro_cuenta);
      end if;
END;
/* Obtener fecha de inicio de devengado de la cuota. */
FUNCTION FU_OBT_FEC_INI_CUOTA
 (P_NRO_CUENTA IN PR_DEVENGADOS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_DEVENGADOS.NRO_CUOTA%TYPE
 )
 RETURN DATE
 IS
v_fec_inicio pr_cta_prestamos.fec_inicio%type;
BEGIN
   select fec_vencimiento
     into v_fec_inicio
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and nro_cuota = p_nro_cuota - 1;
    return v_fec_inicio;
exception
   when no_data_found then
      return null;
END;
/* Obtiene la cotizacion de una moneda */ --CIE-605
FUNCTION LF_OBT_COTIZACION
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS
V_VAL_CONVERSION GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   SELECT  val_conversion
   INTO  v_val_conversion
   FROM  ge_cotizaciones a
   WHERE  fecha  = (SELECT max(fecha)
                          FROM ge_cotizaciones
                         WHERE cod_moneda = p_cod_moneda
                           AND fecha <= P_FEC_TRANSACCION)
   AND  cod_moneda = p_cod_moneda;
   Return v_val_conversion;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_conversion := NULL;
      Return v_val_conversion;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Al buscar Cotizacion '||SQLERRM);
END;
/* Obtiene el valor del parametro */ --CIE-605
FUNCTION LF_OBT_PARDINAMICO 
  (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
 ,P_COD_MODULO IN NUMBER DEFAULT NULL
 ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
 ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
 ,P_COD_OFICINA IN NUMBER  DEFAULT NULL
 ,P_COD_SUB_MODALIDAD IN varchar2 DEFAULT NULL
 )
 RETURN VARCHAR2
 IS
v_val_parametro ge_par_dinamicos.val_parametro%type;
cursor param is
   select /*+ RULE */ val_parametro
     from ge_par_dinamicos
    where nvl(cod_modulo,nvl(p_cod_modulo,-1)) = nvl(p_cod_modulo,-1)
      and nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
      and nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
      and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
      and nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
      and parametro = p_parametro
    order by decode(cod_modulo,null,0,1) +
             decode(cod_modalidad,null,0,1) +
             decode(cod_sub_modalidad,null,0,1) +
             decode(cod_oficina,null,0,1) +
             decode(cod_moneda,null,0,1) desc;  
BEGIN
   open param;
   fetch param into v_val_parametro;
   if param%notfound then
      close param;
      raise no_data_found;
   else
      close param;
   end if;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
END;
/* Obtiene el capital acumulado. */ -- CIE-605
FUNCTION LF_OBT_CAPITAL_ACUMU
 (P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN number
 IS

V_MTO_CAPITAL PR_CTA_PRESTAMOS.MTO_CAPITAL%TYPE;
BEGIN
SELECT SUM(NVL(PR_CUOTAS.MTO_CAPITAL,0) + NVL(PR_CUOTAS.MTO_INT_DOCUMENTADO,0) - NVL(PR_CUOTAS.MTO_CAP_ADELANTADO,0))
INTO v_mto_capital
FROM PR_CUOTAS
WHERE PR_CUOTAS.ESTADO <> 'N'
AND PR_CUOTAS.FEC_VENCIMIENTO > p_fec_inicio
and PR_CUOTAS.NRO_CUENTA = p_nro_cuenta;
RETURN v_mto_capital;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  raise_application_error(-20000, 'ERROR al obtener capital acumulado ');
WHEN OTHERS THEN
  raise_application_error(-20000, 'ERROR al buscar valor acumulado '||
                                        'de capital en PR_CUOTAS');
END;

/* Insertar devengados segun nuevo esquema (unificado con CDA). */
PROCEDURE PR_INS_PR_DEVENGADOS
 IS
v_rowid varchar2(100);
BEGIN
   select rowid into v_rowid
     from  pr_devengados
    where nro_cuenta = r_deven.nro_cuenta
      and nro_cuota  = r_deven.nro_cuota
      and tipo       = r_deven.tipo
      and cod_moneda = r_deven.cod_moneda
      and estado     = r_deven.estado
      and categoria  = nvl(r_deven.categoria,1)
      and capital    = r_deven.capital
      and val_tasa   = r_deven.val_tasa;
   --- Actualizar el registro existente.
   if   r_deven.fecha      = PAG_CAL.G_FEC_ANTERIOR + 1
   or  (nvl(v_proceso,'F') = 'I'
    and r_deven.fecha      <> PAG_CAL.G_FEC_ANTERIOR + 1)
   or  (to_char(r_deven.fecha,'YYYYMM') <> to_char(PAG_CAL.G_FEC_ANTERIOR,'YYYYMM')
       and r_deven.fecha = PAG_CAL.G_PRI_DIA_MES) then
      --- No corresponde a fin de semana o feriado
      --- O es el inicio del la mañana del primer dia habil siguiente de
      --- fin de semana o feriados
      --- O hubo un fin de mes en el medio y se esta procesando el primer dia del mes siguiente
      update pr_devengados
         set can_dia_anterior  = nvl(can_dia_interes,0),
             mto_dev_anterior  = mto_dev_actual,
             can_dia_interes   = r_deven.fec_ult_devengado - fec_inicio +1,--nvl(can_dia_interes,0) + r_deven.can_dia_interes,
             mto_dev_actual    = decode(fecha, r_deven.fecha, mto_dev_actual, 0) + nvl(r_deven.mto_dev_actual,0), -- DYDMR-26. CB. 11/04/2014
             mto_ajuste        = nvl(r_deven.mto_ajuste,0),
             mto_dev_acumulado = mto_dev_acumulado + nvl(r_deven.mto_dev_actual,0),
             fecha             = r_deven.fecha,
             fec_ult_devengado = r_deven.fec_ult_devengado
       where nro_cuenta = r_deven.nro_cuenta
         and nro_cuota  = r_deven.nro_cuota
         and tipo       = r_deven.tipo
         and cod_moneda = r_deven.cod_moneda
         and estado     = r_deven.estado
         and categoria  = nvl(r_deven.categoria,1)
         and capital    = r_deven.capital
         and val_tasa   = r_deven.val_tasa;
   else
      --- Existio un feriado o fin de semana y debe acumular
      --- para asentar todo el dia habil en el cierre
      update pr_devengados      --sólo la diferencia entre lo ya devengado y lo q está devengando ahora
         set can_dia_anterior  = nvl(can_dia_interes,0), -- BBVASOP-1142 19/10/2012. Actualizar el mto y día
             mto_dev_anterior  = mto_dev_actual,  -- anterior antes de modificar los actuales.-
             can_dia_interes   = r_deven.fec_ult_devengado - fec_inicio +1,
             mto_dev_actual    = decode(tipo,'N',decode(v_acu_devengado, 'N', 0, mto_dev_actual),mto_dev_actual) + nvl(r_deven.mto_dev_actual,0), -- RABP-CNF-02-01-2015: DYDMR-1472  (27-10-2014: CNFPCI-52(JIRA))
             mto_ajuste        = nvl(mto_ajuste,0) + nvl(r_deven.mto_ajuste,0),
             mto_dev_acumulado = mto_dev_acumulado + nvl(r_deven.mto_dev_actual,0),
             fecha             = r_deven.fecha,
             fec_ult_devengado = r_deven.fec_ult_devengado
       where nro_cuenta = r_deven.nro_cuenta
         and nro_cuota  = r_deven.nro_cuota
         and tipo       = r_deven.tipo
         and cod_moneda = r_deven.cod_moneda
         and estado     = r_deven.estado
         and categoria  = nvl(r_deven.categoria,1)
         and capital    = r_deven.capital
         and val_tasa   = r_deven.val_tasa;
   end if;
exception
   when no_data_found then
      insert into pr_devengados(
         nro_cuenta, nro_cuota, tipo, fecha,
         fec_inicio, fec_ult_devengado, cod_moneda,
         estado, categoria, capital, val_tasa,
         can_dia_interes, mto_dev_anterior, can_dia_anterior,
         mto_dev_actual, mto_ajuste, mto_dev_acumulado)
      values
        (r_deven.nro_cuenta, r_deven.nro_cuota, r_deven.tipo, r_deven.fecha,
         r_deven.fec_inicio, r_deven.fec_ult_devengado, r_deven.cod_moneda,
         r_deven.estado, nvl(r_deven.categoria,1), r_deven.capital, r_deven.val_tasa,
         r_deven.can_dia_interes, nvl(r_deven.mto_dev_anterior,0), r_deven.can_dia_anterior,
         r_deven.mto_dev_actual, r_deven.mto_ajuste,
         nvl(r_deven.mto_dev_anterior,0)+nvl(r_deven.mto_dev_acumulado,0));
   WHEN OTHERS THEN
      if sqlcode = -54 then
         raise_application_error(-20000,'Reg. de Devengado Cta. '||r_deven.nro_cuenta||' bloqueado por otro usuario');
      end if;
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||'Actu. PR_DEVENGADOS cta '||r_deven.nro_cuenta );
      end if;
END;
/* Proceso de devengado en el momento del cobro de la cuota. */
PROCEDURE PR_PRO_DEV_COB_CUO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_FEC_HASTA IN DATE
 ,P_HORA IN VARCHAR2
 ,P_MTO_COBRO IN PR_CTA_PRESTAMOS.SAL_CAP_BATCH%TYPE
 ,P_DESCUENTO IN PR_CTA_PRESTAMOS.SAL_CAP_BATCH%TYPE
 ,P_SAL_INTERES IN PR_CTA_PRESTAMOS.SAL_CAP_BATCH%TYPE
 ,P_FEC_VTO_CUO IN DATE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 )
 IS
   V_MONE_LOCAL     BA_MONEDAS.COD_MONEDA%TYPE;
   V_MONE_FUERTE    BA_MONEDAS.COD_MONEDA%TYPE;
   V_COTIZACION     GE_COTIZACIONES.VAL_CONVERSION%TYPE;
   V_INTERES        PR_CUOTAS.MTO_INTERES%TYPE;
   V_CAPITAL        PR_CUOTAS.MTO_CAPITAL%TYPE;
   V_TASA           NUMBER;
   V_FEC_INI        DATE;
   V_FEC_FIN        DATE;
   V_FEC_ULT_DEV    DATE;
   V_NRO_CUENTA     PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE;
   v_categoria      ge_clientes.cat_automatica%type;
   ulthabm          date;
   ultdiam          date;
   fcproxi          date;
   prihabm          date;
   pridiam          date;
   v_cotiz_fuerte   ge_cotizaciones.val_venta%type;
   ----
   cuo              pr_cuotas%rowtype;
   reg              pr_cta_prestamos%rowtype;
   v_dev_no_cobrado pr_cuotas.dev_acumulado%type;
   v_dev_suspenso   pr_cuotas.dev_acumulado%type;
   v_devengo        varchar2(1);
   v_fec_ini_dev    pr_devengados.fec_inicio%type;
   v_fec_fin_dev    pr_devengados.fec_inicio%type;
   v_int_diario     pr_cuotas.mto_interes%type;
   v_actu_nocob     pr_cuotas.dev_no_cobrado%type;
   v_actu_susp      pr_cuotas.dev_suspenso%type;
   v_mto_cuota      pr_cuotas.mto_interes%type;
   v_fec_actual     date := pag_cal.FU_OBT_FEC_ACTUAL(6);
BEGIN
   v_acu_devengado := 'S'; --RABP-CNF-02-01-2015: Variable que indica que se debe acumular el devengado en pr_ins_pr_devengados
   PAG_CAL.PR_OBT_DAT_CALENDAR(6); -- agregado el 15/12/2005
   v_dev_ant_can_par := 0;  /*dydmr 2003 fm 09/07/2015 */ -- SC 12793 / EP 2015-06 - N.AN. almacena devengado acumulado antes de cancelacion parcial de capital
   -- basicamente tiene q actualizar las cuotas y el prestamo y tablas de devengado si corresponde
   if nvl(p_mto_cobro,0) + nvl(p_descuento,0) <= 0 then
      return;
   end if;
   v_fec_sist   := p_fec_hasta; --fecha valor
   v_horamovim  := p_hora;
   v_mone_local := PAG_GEN.FU_OBT_MON_LOCAL;
   v_secuencia  := nvl(p_nro_secuencia,0);
   --- Recupera datos del prestamo
   Begin
      select p.*
        into reg
        from pr_cta_prestamos p
       where nro_cuenta = p_nro_cuenta;
   exception
      when no_data_found then
         raise_application_error(-20000,
         'Prestamo '||p_nro_cuenta||' no registrada');
   End;
   v_estado        := reg.estado;
   v_moneda        := reg.cod_moneda;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo, reg.cod_modalidad, reg.cod_moneda, reg.cod_oficina);
   --- Recuperar categoria del cliente del prestamo
   Begin
      select fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
             c.cod_persona
        into v_categoria, v_cod_persona
        from ge_clientes c, ge_cta_clientes b
       where b.nro_cuenta  = p_nro_cuenta
         and b.cod_persona = c.cod_persona
         and b.relacion    = 'P';
      if v_categoria <> 1 and reg.cod_modalidad in (670,671) then
         --- Bienes siempre debe devengar en no cobrado, por eso se
         --- ajusta la categoria
         v_categoria := 1;
      end if;
   exception
      when no_data_found then
         raise_application_error(-20000,
         'Cliente Principal no registrado para cuenta '||p_nro_cuenta);
   End;
   --- Recuperar datos de la cuota a devengar
   Begin
      select c.*
        into cuo
        from pr_cuotas c
       WHERE nro_cuenta = p_nro_cuenta
         and nro_cuota  = p_nro_cuota;
      exception
         when no_data_found then
            raise_application_error(-20000,
            'Cuota '||p_nro_cuota||' prestamo '||p_nro_cuenta||' no registrada');
   End;
   --- Calcular fecha de inicio de devengado de la cuota
   if reg.tip_interes = 'V' then
      --- Para prestamos vencidos recorrer cuotas cuya fecha de
      --- inicio de devengado ha transcurrido
      v_fec_ini_dev := nvl(FU_OBT_FEC_INI_CUOTA(reg.nro_cuenta, cuo.nro_cuota),reg.fec_inicio);
   else
      v_fec_ini_dev := reg.fec_inicio;
   end if;
   -- SC 12793 / EP 2015-06 - N.AN. Recupera dev anterior acancelacion parcial en caso que exista para la cuota
   -- si hay mas de un registro para la cuota se toma el ultimo, el de mayor fecha, que no este reversado
   /*dydmr 2003 fm 09/07/2015 */
   begin
      select a.dev_acumulado, a.fecha
                   into v_dev_ant_can_par, v_fec_ini_dev
      from PR_COB_AMO_PARCIAL a
      where a.nro_cuenta = P_NRO_CUENTA
      and a.nro_cuota = P_NRO_CUOTA
      and a.reversado='N'
      and a.fec_insercion = (select max(fec_insercion)
                                   from pr_cob_amo_parcial b
                                   where b.nro_cuenta = a.nro_cuenta
                                    and b.nro_cuota = a.nro_cuota
                                    and b.reversado = 'N');
    EXCEPTION
        WHEN OTHERS THEN
          v_dev_ant_can_par := 0;
    end;
   --- Recuperar capital segun el tipo de prestamo
   if reg.tip_interes = 'A' then
      v_capital := nvl(cuo.mto_capital,0) + nvl(cuo.mto_int_documentado,0) - nvl(cuo.mto_cap_adelantado,0);
   else
      v_capital := PAP_INT.FU_OBT_CAPITAL_ACUMU(v_fec_ini_dev, reg.nro_cuenta);
   end if;
   v_interes        := 0;
   v_dev_no_cobrado := 0;
   v_dev_suspenso   := 0;
   v_devengo        := 'N';

   --- Verificar si cancela o no la cuota
   if nvl(cuo.sal_interes,0) + nvl(cuo.sal_int_documentado,0) <=
      nvl(p_mto_cobro,0)     + nvl(p_descuento,0) then
      --- Cancela el interes de la cuota
       /*dydmr 2003 fm 09/07/2015 */
      if nvl(cuo.dev_acumulado,0) - nvl(v_dev_ant_can_par,0)    <>
        (nvl(cuo.mto_interes,0)        + nvl(cuo.mto_int_documentado,0)) -
        (nvl(cuo.mto_int_descontado,0) + nvl(p_descuento,0))            then
         --- Verificar si debe devengarse la cuota
          /*dydmr 2003 fm 09/07/2015 */
    --- SC 12793 / EP 2015-06 - N.AN. suma el dev acumulado anterior a cancelacion parcial para evitar dar devengado negativo

       v_interes := (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0) - (nvl(cuo.mto_int_descontado,0)
       + nvl(p_descuento,0))) - nvl(cuo.dev_acumulado,0)/* + nvl(v_dev_ant_can_par,0)*/;

       IF reg.estado IN ('A','C') AND v_categoria IN (1,2) THEN /* solo los est 'A' y 'C' y categ 1 y 2*/
            v_dev_no_cobrado := v_interes;
            r_deven.tipo     := 'N';
         else
            v_dev_suspenso   := v_interes;
            r_deven.tipo     := 'S';
         end if;
         --- Verificar si debe descontarse de utilidad
         if v_interes < 0 then
            --- Se devengo de mas
            if nvl(cuo.dev_no_cobrado,0) >= abs(v_interes) then
               -- Desafectar de utilidad por devengado del cobro
               v_dev_no_cobrado := nvl(v_interes,0);
               v_dev_suspenso   := 0;
            else
               --- Desafectar del devengado no cobrado y luego del suspendido
               if nvl(cuo.dev_no_cobrado,0) > 0 then
                  v_dev_no_cobrado := nvl(cuo.dev_no_cobrado,0)*-1;
                  v_dev_suspenso   := 0;
               end if;
               if nvl(cuo.dev_suspenso,0) >= abs(v_interes) then
                  v_dev_suspenso := nvl(v_interes,0);
               else
                  v_dev_suspenso := nvl(cuo.dev_suspenso,0)*-1;
               end if;
            end if;
         end if;
      end if;
--      r_deven.fec_ult_devengado := cuo.fec_vencimiento;
      r_deven.fec_ult_devengado := cuo.fec_vencimiento - 1;
      if v_dev_no_cobrado <> 0 then
         --- Actualizar devengados no cobrados
         r_deven.tipo              := 'N';
         r_deven.nro_cuenta        := p_nro_cuenta;
         r_deven.nro_cuota         := cuo.nro_cuota;
         r_deven.fecha             := v_fec_actual; --fecha actual para contabilidad -- v_fec_sist;
         r_deven.fec_inicio        := v_fec_ini_dev;
         r_deven.fec_ult_devengado := r_deven.fec_ult_devengado;
         r_deven.cod_moneda        := reg.cod_moneda;
         r_deven.estado            := reg.estado;
         r_deven.categoria         := v_categoria;
         r_deven.capital           := v_capital;
         r_deven.val_tasa          := reg.val_tasa;
         r_deven.can_dia_interes   := r_deven.fec_ult_devengado - v_fec_ini_dev /*v_fec_sist*/ + 1;
         r_deven.mto_dev_actual    := v_dev_no_cobrado;
         r_deven.mto_dev_acumulado := v_dev_no_cobrado;
         pr_ins_pr_devengados;
         v_devengo := 'S';
      end if;
      if v_dev_suspenso <> 0 then
         --- Actualizar devengados en suspenso
         r_deven.tipo              := 'S';
         r_deven.nro_cuenta        := p_nro_cuenta;
         r_deven.nro_cuota         := cuo.nro_cuota;
         r_deven.fecha             := v_fec_actual;--v_fec_sist;
         r_deven.fec_inicio        := v_fec_ini_dev;
         r_deven.fec_ult_devengado := r_deven.fec_ult_devengado;
         r_deven.cod_moneda        := reg.cod_moneda;
         r_deven.estado            := reg.estado;
         r_deven.categoria         := v_categoria;
         r_deven.capital           := v_capital;
         r_deven.val_tasa          := reg.val_tasa;
         r_deven.can_dia_interes   := r_deven.fec_ult_devengado - v_fec_ini_dev /*v_fec_sist*/ + 1;
         r_deven.mto_dev_actual    := v_dev_suspenso;
         r_deven.mto_dev_acumulado := v_dev_suspenso;
         pr_ins_pr_devengados;
         v_devengo := 'S';
      end if;
      /*
      || DYDMR-445 Incorrecto devengamiento de intereses - SPI 3188
      || xpy0038 - 13/06/2014: debe actualizar el campo FEC_ULT_DEVENGADO
      || para los casos donde se otorgue el descuento total
      || de los Intereses a Devengar de la cuota a cancelar.
      */
      if  nvl(p_descuento,0) > 0 then
         update pr_devengados
            set /*fecha             = v_fec_actual,*/--DYDMR-4506 - ITGF - Devengamiento de Intereses - Cta. Nº 1166804810
                fec_ult_devengado = r_deven.fec_ult_devengado
          where nro_cuenta        = p_nro_cuenta
            and nro_cuota         = cuo.nro_cuota
            --and tipo              = 'S' --Suspenso 'N'/No
            and cod_moneda        = reg.cod_moneda
            and estado            = reg.estado
            and categoria         = v_categoria
            and capital           = v_capital
            and val_tasa          = reg.val_tasa;

         update pr_cta_prestamos --DYDMR-4060 / ITGF - Inconsistencia en Devengado de Préstamos
            set fec_ult_devengado = r_deven.fec_ult_devengado
          where nro_cuenta        = p_nro_cuenta;
      end if;
   else --- Si no cancela la cuota
      --- Se debe verificar si el monto cobrado corresponde a la fecha
      --- hacer por regla de tres simple
      --- Calcular Interes devengado correspondiente a un dia
      v_int_diario := PAP_DEV.FU_CAL_INTERES(v_fec_sist, v_fec_sist, v_capital,
                                             reg.nro_solicitud, reg.val_tasa,
                                             cuo.nro_cuenta, cuo.nro_cuota );
                                             --- Se agregó nro de cuenta y cuota
                                             --- para calculo de tasas variables
      v_int_diario := round(v_int_diario, v_redondeo);
       /*dydmr 2003 fm 09/07/2015 */
      if nvl(p_mto_cobro,0) > nvl(cuo.dev_acumulado,0)- nvl(v_dev_ant_can_par,0) then
         v_interes := nvl(p_mto_cobro,0) - nvl(cuo.dev_acumulado,0) + nvl(v_dev_ant_can_par,0);
         IF reg.estado IN ('A','C') AND v_categoria IN (1,2) THEN /* solo los est 'A' y 'C' y categ 1 y 2*/
            v_dev_no_cobrado := v_interes;
            r_deven.tipo     := 'N';
         else
            v_dev_suspenso   := v_interes;
            r_deven.tipo     := 'S';
         end if;
         --- Calcular fecha de ultimo devengado. Obs. 01/07/2010: se agregó el NVL para que utilice la fecha de Inicio del Préstamo si no tiene FEC_ULT_DEVENGADO.
         r_deven.fec_ult_devengado := nvl(reg.fec_ult_devengado,reg.fec_inicio) + (floor(nvl(v_interes,0)/nvl(v_int_diario,0)));
         --- Insertar devengados
         r_deven.nro_cuenta        := p_nro_cuenta;
         r_deven.nro_cuota         := cuo.nro_cuota;
         r_deven.fecha             := v_fec_actual;--v_fec_sist;
         r_deven.fec_inicio        := v_fec_ini_dev;
         r_deven.fec_ult_devengado := r_deven.fec_ult_devengado;
         r_deven.cod_moneda        := reg.cod_moneda;
         r_deven.estado            := reg.estado;
         r_deven.categoria         := v_categoria;
         r_deven.capital           := v_capital;
         r_deven.val_tasa          := reg.val_tasa;
         r_deven.can_dia_interes   := r_deven.fec_ult_devengado - v_fec_ini_dev/*v_fec_sist*/ + 1;
         r_deven.mto_dev_actual    := v_interes;
         r_deven.mto_dev_acumulado := v_interes;
         pr_ins_pr_devengados;
         v_devengo := 'S';
      end if;
   end if;
   If v_devengo = 'S' then
     -- Solo si devengo debe actualizar.
     --- Actualizar cuotas
     update pr_cuotas    --solo si es no docum actualiza el dev_no_cobrado y el dev_suspenso
        set dev_no_cobrado = nvl(dev_no_cobrado,0) + nvl(v_dev_no_cobrado,0),
            dev_suspenso   = nvl(dev_suspenso,0)   + nvl(v_dev_suspenso,0),
            dev_acumulado  = nvl(dev_acumulado,0)  + nvl(v_dev_no_cobrado,0) + nvl(v_dev_suspenso,0),
            mto_int_descontado = nvl(mto_int_descontado,0) +  nvl(p_descuento,0)
      where nro_cuenta = p_nro_cuenta
        and nro_cuota  = p_nro_cuota;
   else
     update pr_cuotas
        set mto_int_descontado = nvl(mto_int_descontado,0) +  nvl(p_descuento,0)
      where nro_cuenta = p_nro_cuenta
        and nro_cuota  = p_nro_cuota;
   End if;
   --- Actualizar maestro de prestamos
   if reg.tip_interes = 'V' then
      v_fec_fin := r_deven.fec_ult_devengado;
   else
      --- para intereses Adelantados no debe actualizar fecha de ultimo devengado
      v_fec_fin := null;
   end if;
   if v_devengo = 'S' then
     -- Solo si devengo debe actualizar.
     update pr_cta_prestamos
        set val_int_devengar  = nvl(val_int_devengar,0) - (nvl(v_dev_suspenso,0) + nvl(v_dev_no_cobrado,0) + nvl(p_descuento,0)),
            dev_acumulado     = nvl(dev_acumulado,0)    + (nvl(v_dev_suspenso,0) + nvl(v_dev_no_cobrado,0)),
            dev_suspenso      = nvl(dev_suspenso,0)     +  nvl(v_dev_suspenso,0),
            dev_no_cobrado    = nvl(dev_no_cobrado,0)   +  nvl(v_dev_no_cobrado,0),
            fec_ult_devengado = nvl(v_fec_fin, fec_ult_devengado)
      where nro_cuenta = p_nro_cuenta;
   else
     update pr_cta_prestamos
        set val_int_devengar  = nvl(val_int_devengar,0) - nvl(p_descuento,0)
      where nro_cuenta = p_nro_cuenta;
   End If;
   --- Verificar los montos pagados
   v_actu_nocob := 0;
   v_actu_susp  := 0;
   v_mto_cuota  := nvl(p_mto_cobro,0) + nvl(p_descuento,0);
   -- Cubrir el dev_no_cobrado, luego el suspendido, y el acumulado (si no hay en no_cobrado
   -- ni suspenso se devengo en vigente -> ya esta en acum)
   if nvl(cuo.dev_no_cobrado,0) + nvl(v_dev_no_cobrado,0) > 0 then
      if v_mto_cuota >= nvl(cuo.dev_no_cobrado,0)  + nvl(v_dev_no_cobrado,0) then
         v_actu_nocob := nvl(cuo.dev_no_cobrado,0) + nvl(v_dev_no_cobrado,0);
         v_mto_cuota  := v_mto_cuota - v_actu_nocob;
      else  --se cubre lo q alcanza del no_cobrado
         v_actu_nocob := v_mto_cuota;
         v_mto_cuota  := 0;
      end if;
   end if;
   -- Suspendido
   if v_mto_cuota > 0 and nvl(cuo.dev_suspenso,0) + nvl(v_dev_suspenso,0) > 0 then
      if v_mto_cuota >= nvl(cuo.dev_suspenso,0) + nvl(v_dev_suspenso,0) then
         v_actu_susp := nvl(cuo.dev_suspenso,0) + nvl(v_dev_suspenso,0);
         v_mto_cuota := v_mto_cuota - v_actu_susp;
      else
         v_actu_susp := v_mto_cuota;
         v_mto_cuota := 0;
      end if;
   end if;
   if nvl(v_actu_susp,0) > 0 or nvl(v_actu_nocob,0) > 0 then
      --- actualizar la cuota
      update pr_cuotas
         set dev_no_cobrado = nvl(dev_no_cobrado,0) - nvl(v_actu_nocob,0),
             dev_suspenso   = nvl(dev_suspenso,0)   - nvl(v_actu_susp,0)
       where nro_cuenta = p_nro_cuenta
         and nro_cuota  = p_nro_cuota;
      -- actualizar el maestro de prestamos
      update pr_cta_prestamos
         set dev_suspenso   = nvl(dev_suspenso,0)   - nvl(v_actu_susp,0),
             dev_no_cobrado = nvl(dev_no_cobrado,0) - nvl(v_actu_nocob,0)
       where nro_cuenta = p_nro_cuenta;
      --- generar el movimiento por el suspenso
      if nvl(v_actu_susp,0) > 0 then
         v_tot_interes := v_actu_susp; --- Se debe desafectar - Generar utilidad
         PR_INS_ASIE_CONTABLE(reg.cod_modulo, reg.cod_modalidad, reg.cod_oficina,
            p_nro_cuenta, NULL, 'S', cuo.nro_cuota,'DEVENGADO EN SUSPENSO');--pasarle los parametros de movimiento
      end if;
   end if;
   p_nro_secuencia := v_secuencia;
EXCEPTION
    WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||' Dev. en Cobro') ;
      end if;
END;
PROCEDURE PR_INS_ASIE_CONTABLE
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_IND_ENCOBRO IN VARCHAR2
 ,P_NRO_CUOTA IN NUMBER := null
 ,P_CONCEPTO IN VARCHAR2 := null
 )
 IS

r_mvto ge_movimientos%rowtype;
BEGIN
   if v_secuencia + 3 > 999 then
      v_secuencia := 0;
      v_horamovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_horamovim);
   end if;
   r_mvto.cod_usuario     := upper(user);
   r_mvto.hora            := v_horamovim;
   r_mvto.cod_modulo      := p_cod_modulo;    --definir hijo
   r_mvto.cod_modalidad   := p_cod_modalidad; --definir hijo
   r_mvto.cod_oficina     := p_cod_oficina;
   r_mvto.nro_cuenta      := p_nro_cuenta;
   r_mvto.cod_moneda      := v_moneda;
   r_mvto.cod_tra_padre   := 900;
   r_mvto.fecha           := pag_cal.FU_OBT_FEC_ACTUAL(6);--v_fec_sist;
   r_mvto.fec_valor       := v_fec_sist;
   r_mvto.nro_documento   := NULL;
   r_mvto.monto           := v_tot_interes;
   r_mvto.estado          := 'N';
   r_mvto.est_cuenta      := v_estado;
   r_mvto.cod_ofi_origen  := p_cod_oficina;
   r_mvto.concepto        := nvl(p_concepto,'INTERES DEVENGADO');
   r_mvto.reversado       := 'N';
   r_mvto.emi_aviso       := 'N';
   r_mvto.protegido       := 'N';
   r_mvto.cod_mod_padre   := p_cod_modulo;
   r_mvto.cod_mad_padre   := p_cod_modalidad;
   r_mvto.nro_documento3  := p_nro_cuota;
   IF p_cod_transaccion IS NULL THEN
      IF P_IND_ENCOBRO = 'S' THEN --DESDE EL PROCESO DE COBRO
         v_secuencia   := v_secuencia + 1;        
         v_cod_tra_hij := 908;
         r_mvto.nro_secuencia   := v_secuencia;
         r_mvto.cod_transaccion := v_cod_tra_hij;
         --- Generar movimiento con cuenta contable asociada
         prg_gen_mov_contable(v_cod_persona, p_nro_cuenta, r_mvto, v_secuencia);
      ELSE--DESDE EL PROCESO DE CIERRE DIARIO
         v_secuencia := v_secuencia + 1;
         v_cod_tra_hij := fu_obt_tra_hij_deb;
         r_mvto.nro_secuencia := v_secuencia;
         r_mvto.cod_transaccion  :=v_cod_tra_hij;
         IF v_cod_tra_hij IS NOT NULL THEN
            pag_gen.pr_ins_ge_movimiento(r_mvto,'N');
         END IF;
      END IF;
      v_secuencia   := v_secuencia + 1;
      if p_ind_encobro = 'S' then
         v_cod_tra_hij := 948;
      else
         v_cod_tra_hij := fu_obt_tra_hij_cre(P_IND_ENCOBRO);
      end if;
      r_mvto.nro_secuencia := v_secuencia;
      r_mvto.cod_transaccion  :=v_cod_tra_hij;
      IF v_cod_tra_hij IS NOT NULL THEN
         if nvl(P_IND_ENCOBRO,'N') = 'N' then
            pag_gen.pr_ins_ge_movimiento(r_mvto,'N');
         else
            prg_gen_mov_contable(v_cod_persona, p_nro_cuenta, r_mvto, v_secuencia);
         end if;
      END IF;
   ELSE
      r_mvto.nro_secuencia := v_secuencia;
      r_mvto.cod_transaccion  := p_cod_transaccion;
      if nvl(P_IND_ENCOBRO,'N') = 'N' then
         pag_gen.pr_ins_ge_movimiento(r_mvto,'N');
      else
         prg_gen_mov_contable(v_cod_persona, p_nro_cuenta, r_mvto, v_secuencia);
      end if;
   END IF;
   v_cod_tra_hij :=null;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000, SQLERRM||' INS_ASIE_CONTABLE, Devengamiento cta. '||p_nro_cuenta);
      end if;
END;

FUNCTION FU_OBT_TRA_HIJ_CRE
 (P_IND_ENCOBRO IN VARCHAR2
 )
 RETURN NUMBER
 IS

v_transaccion number;
BEGIN
   IF P_IND_ENCOBRO = 'S' THEN --DESDE EL PROCESO DE COBRO
               v_transaccion := 901;
   ELSE--DESDE EL CIERRE DIARIO     
            v_transaccion := 901;     
   END IF;
   RETURN v_transaccion;
END;
FUNCTION FU_OBT_TRA_HIJ_DEB
 RETURN NUMBER
 IS

v_transaccion number;
BEGIN   
      v_transaccion := 903;  
   RETURN v_transaccion;
END;
/* Calcula el interes. */
FUNCTION FU_CAL_INTERES
 (P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 ,P_FEC_VENCIMIENTO IN PR_CTA_PRESTAMOS.FEC_VENCIMIENTO%TYPE
 ,P_MTO_CAPITAL IN PR_CTA_PRESTAMOS.MTO_CAPITAL%TYPE
 ,P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
 ,P_VAL_TASA IN PR_CTA_PRESTAMOS.VAL_TASA%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 )
 RETURN NUMBER
 IS

V_INTERES PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
V_INT_CUOTA_PARTIDA PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
V_COD_TAS_FONDO PR_TAS_FONDOS.COD_TAS_FONDO%TYPE;
V_FEC_DESDE PR_TAS_FONDOS.FEC_DESDE%TYPE;
V_VAL_TASA_VIEJA PR_CUOTAS_HIS.VAL_TASA%TYPE;
BEGIN
   begin
      select max(cod_tas_fondo)
      into   v_cod_tas_fondo
      from   pr_cuotas_his
      where  nro_cuenta = p_nro_cuenta
      and    nro_cuota  = p_nro_cuota;
   exception
      when no_data_found then
         v_cod_tas_fondo := 0;
   end;

   --- Verifico si tiene cambio de tasa
   if nvl(v_cod_tas_fondo,0) > 0 then
      --- Obtengo la fecha de cambio de la tasa
      select fec_desde
      into   v_fec_desde
      from   pr_tas_fondos
      where  cod_tas_fondo = v_cod_tas_fondo;
      --- Obtengo la tasa vieja de la cuota
      select val_tasa
      into   v_val_tasa_vieja
      from   pr_cuotas_his
      where  nro_cuenta = p_nro_cuenta
      and    nro_cuota  = p_nro_cuota
      and    cod_tas_fondo = v_cod_tas_fondo;
      ---
      if v_fec_desde > p_fec_inicio then        
         v_int_cuota_partida := pap_int.FU_CAL_INTERES(P_FEC_INICIO, v_fec_desde-1, P_MTO_CAPITAL, null, v_val_tasa_vieja);
         v_interes := pap_int.FU_CAL_INTERES(v_fec_desde, P_FEC_VENCIMIENTO, P_MTO_CAPITAL, null, p_val_tasa);
         v_interes := nvl(v_interes,0) + nvl(v_int_cuota_partida,0);
      else
         --- No es cuota partida y ejecuto calculo de interés original
         V_INTERES := PAP_INT.FU_CAL_INTERES(P_FEC_INICIO, P_FEC_VENCIMIENTO, P_MTO_CAPITAL,null, p_val_tasa);
         ---
      end if;
   else
      --- No tuvo cambio de tasa y ejecuto calculo de interés original
      V_INTERES := PAP_INT.FU_CAL_INTERES(P_FEC_INICIO, P_FEC_VENCIMIENTO, P_MTO_CAPITAL,null, p_val_tasa);
      ---
   end if;
   return V_INTERES;
END;

END PAP_DEV;

