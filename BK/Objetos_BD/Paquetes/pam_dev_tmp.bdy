create or replace package body it.PAM_DEV_TMP is

V_SECUENCIA         NUMBER;
V_HORAMOVIM         VARCHAR2(8);
V_MONEDA            VARCHAR2(3);
V_FEC_SIST          DATE;
V_ESTADO            md_cta_documentos.ESTADO%TYPE;
v_fec_ult_devengado date;
v_proceso           varchar2(01);
r_deven             md_devengados%rowtype;
function lf_obt_dia_devengado(p_ini_cuota in  date,p_fin_cuota in date,p_fec_ini_dev in date,p_fec_fin_dev in date)
  return number is
v_dias number := 0;
v_inicio date;
v_fin date;
begin
  if p_ini_cuota > p_fec_ini_dev then
     v_inicio := p_ini_cuota;
  else
     v_inicio := p_fec_ini_dev;
  end if;
  if p_fin_cuota < p_fec_fin_dev then
     v_fin := p_fin_cuota;
  else
     v_fin := p_fec_fin_dev;
  end if;
  v_dias := v_fin - v_inicio + 1;
  return v_dias;
end;
/* Insertar devengados */
PROCEDURE PR_INS_MD_DEVENGADOS
 IS
 v_rowid varchar2(100);
BEGIN
   select rowid into v_rowid
     from md_devengados
    where nro_cuenta = r_deven.nro_cuenta
      and cod_moneda = r_deven.cod_moneda
      and estado     = r_deven.estado
      and capital    = r_deven.capital
      and val_tasa   = r_deven.val_tasa;
   --- Actualizar el registro existente.
   if r_deven.fecha = (PAG_CAL.G_FEC_ANTERIOR + 1)  or  (nvl(v_proceso,'F') = 'I'
      and r_deven.fecha      <> PAG_CAL.G_FEC_ANTERIOR + 1)
      or  (to_char(r_deven.fecha,'YYYYMM') <> to_char(PAG_CAL.G_FEC_ANTERIOR,'YYYYMM')
      and r_deven.fecha = PAG_CAL.G_PRI_DIA_MES) then
      --- No corresponde a fin de semana o feriado
      --- O es el inicio del la mañana del primer dia habil siguiente de
      --- fin de semana o feriados
      --- O hubo un fin de mes en el medio y se esta procesando el primer dia del mes siguiente
      update md_devengados
         set can_dia_anterior  = nvl(can_dia_interes,0),
             mto_dev_anterior  = nvl(mto_dev_actual,0),
             can_dia_interes   = nvl(can_dia_interes,0) + r_deven.can_dia_interes,
             mto_dev_actual    = nvl(r_deven.mto_dev_actual,0),
             mto_ajuste        = nvl(r_deven.mto_ajuste,0),
             mto_dev_acumulado = nvl(mto_dev_acumulado,0) + nvl(r_deven.mto_dev_actual,0),
             fecha             = r_deven.fecha,
             fec_ult_devengado = r_deven.fec_ult_devengado
       where nro_cuenta = r_deven.nro_cuenta
         and cod_moneda = r_deven.cod_moneda
         and estado     = r_deven.estado
         and capital    = r_deven.capital
         and val_tasa   = r_deven.val_tasa;
   else
      --- Existio un feriado o fin de semana y debe acumular
      --- para asentar todo el dia habil en el cierre
      update md_devengados
         set can_dia_interes   = nvl(can_dia_interes,0) + r_deven.can_dia_interes,
             mto_dev_actual    = nvl(mto_dev_actual,0) + nvl(r_deven.mto_dev_actual,0),
             mto_ajuste        = nvl(mto_ajuste,0) + nvl(r_deven.mto_ajuste,0),
             mto_dev_acumulado = nvl(mto_dev_acumulado,0) + nvl(r_deven.mto_dev_actual,0),
             fecha             = r_deven.fecha,
             fec_ult_devengado = r_deven.fec_ult_devengado
       where nro_cuenta = r_deven.nro_cuenta
         and cod_moneda = r_deven.cod_moneda
         and estado     = r_deven.estado
         and capital    = r_deven.capital
         and val_tasa   = r_deven.val_tasa;
   end if;
exception
   when no_data_found then
      insert into md_devengados(
         nro_cuenta,fecha,fec_inicio, fec_ult_devengado, cod_moneda,
         estado, capital, val_tasa,can_dia_interes, mto_dev_anterior, can_dia_anterior,
         mto_dev_actual, mto_ajuste, mto_dev_acumulado)
      values
        (r_deven.nro_cuenta, r_deven.fecha,r_deven.fec_inicio, r_deven.fec_ult_devengado,
         r_deven.cod_moneda, r_deven.estado, r_deven.capital, r_deven.val_tasa,
         r_deven.can_dia_interes, nvl(r_deven.mto_dev_anterior,0), nvl(r_deven.can_dia_anterior,0),
         r_deven.mto_dev_actual, r_deven.mto_ajuste,
         nvl(r_deven.mto_dev_anterior,0)+nvl(r_deven.mto_dev_acumulado,0));
   WHEN OTHERS THEN
      if sqlcode = -54 then
         raise_application_error(-20000,'Reg. de Devengado Cta. '||r_deven.nro_cuenta||' bloqueado por otro usuario');
      end if;
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||'Actu. MD_DEVENGADOS cta '||r_deven.nro_cuenta );
      end if;
END;
/* Generar devengado del documento */
PROCEDURE PR_PRO_DEV_DOCUMENTO
 (P_PROCESO IN VARCHAR2
 )
 IS
   v_mone_local      ba_monedas.cod_moneda%type;
   v_mone_fuerte     ba_monedas.cod_moneda%type;
   v_cotizacion      number;
   v_interes         pr_cuotas.mto_interes%type;
   v_capital         pr_cuotas.mto_capital%type;
   v_tasa            number;
   v_fec_ini         date;
   v_fec_fin         date;
   v_fec_ult_dev     date;
   v_nro_cuenta      pr_cta_prestamos.nro_cuenta%type;
   ulthabm           date;
   ultdiam           date;

   v_cotiz_fuerte    ge_cotizaciones.val_venta%type;
   v_redondeo        number(1);
   ---
   v_dev_acumulado   md_devengados.mto_dev_acumulado%type;
   v_dia_devengado   md_devengados.can_dia_interes%type;
   v_dev_suspenso    pr_cuotas.dev_suspenso%type;
   v_dev_no_cobrado  pr_cuotas.dev_no_cobrado%type;
   v_mto_ajuste      pr_devengados.mto_ajuste%type;
   v_fec_ini_dev     pr_devengados.fec_inicio%type;
   v_fec_fin_dev     pr_devengados.fec_inicio%type;
   v_plz_letra_ant   Number;
   v_plz_letra_act   Number;
   v_val_pre_ant     Number;
   v_val_pre_act     Number;
   v_dia_dev_cuota   number;
   --- Definicion del cursor de documentos vigentes a procesar
   cursor c_documentos IS
   SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.monto,
          val_int_devengar, val_tasa, fec_inicio, fec_vencimiento, a.estado,
          sal_interes, cod_moneda, NVL(fec_ult_devengado, NULL) fec_ult_devengado,
          c.cod_gru_economico, fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
          tip_calculo, a.val_presente,a.sal_val_presente, a.mto_interes, a.dev_acumulado,
          a.dia_ano, a.tot_int_descontado, a.sal_capital
     FROM ge_clientes c, ge_cta_clientes b, md_cta_documentos a
    WHERE c.cod_persona = b.cod_persona
      and b.nro_cuenta  = a.nro_cuenta
      and b.relacion    = 'P'
      and a.estado not in ('S','N')  --- No incluir Canceladas
      and a.cod_modalidad <> 113 --crédito tributario no devenga
      --- Que no tome cuentas vencidas aunque no halla devengado todo
      and (a.cod_modalidad in (109,110) or a.fec_vencimiento > decode(v_fec_sist,v_fec_fin,v_fec_sist,(v_fec_fin - 1)))
      --- No debe devengar las cuentas canceladas por adelantado
      and nvl(a.fec_ult_devengado,a.fec_inicio-1) < v_fec_fin
      and a.fec_inicio <= v_fec_sist
      and (nvl(a.sal_interes,0) > 0 or a.cod_modalidad in (109,110))
                and a.nro_cuenta in ( '3110013100',
                                      '3110013150',
                                      '3110013207',
                                      '3110013258',
                                      '3110013304',
                                      '3110013355',
                                      '3110012502',
                                      '3110012553',
                                      '3110012600',
                                      '3110012650',
                                      '3110012707',
                                      '3110012758',
                                      '3110012804',
                                      '3110012855',
                                      '3110012901',
                                      '3110012952',
                                      '3110013002',
                                      '3110013053',
                                      '3110013401',
                                      '3110013452',
                                      '3110013509',
                                      '3110013550',
                                      '3110014653',
                                      '3110014700',
                                      '3110014750',
                                      '3110014807',
                                      '3110014858',
                                      '3110014904',
                                      '3110014955',
                                      '3110015005',
                                      '3110013606',
                                      '3110013657',
                                      '3110013703',
                                      '3110013754',
                                      '3110013800',
                                      '3110013851',
                                      '3110013908',
                                      '3110013959',
                                      '3110014009',
                                      '3110014050',
                                      '3110014106',
                                      '3110014157',
                                      '3110014203',
                                      '3110014254',
                                      '3110014300',
                                      '3110014351',
                                      '3110014408',
                                      '3110014459',
                                      '3110014505',
                                      '3110014556',
                                      '3110014602',
                                      '3110015072',
                                      '3110015145',
                                      '3110015218',
                                      '3110015285',
                                      '3110015358',
                                      '3110015420',
                                      '3110015498',
                                      '3110015560',
                                      '3110015633',
                                      '3110015706',
                                      '3110015773',
                                      '3110015846')
      --- Cuando devenga de mas tambien debe incluir
      and (nvl(dev_acumulado,0) <> nvl(mto_interes,0) or a.cod_modalidad in (109,110));

    cursor cuotas is
        select  nro_cuota, mto_interes, sal_interes, fec_vencimiento,
        case
          when fec_ult_pago>(fec_vencimiento-plazo) then
             fec_vencimiento-fec_ult_pago
          else
             plazo
        end plazo
          from md_doc_detalles
         where nro_cuenta = v_nro_cuenta
           and estado != 'N'
           and fec_vencimiento > V_FEC_FIN
           and fec_vencimiento - plazo  <= v_fec_sist;

BEGIN
  --
  pag_cal.pr_obt_dat_calendar(10);
  v_fec_sist     := to_date('11112009','ddmmyyyy');--pag_cal.g_fec_actual;
  ulthabm        := pag_cal.g_ult_dia_mes_habil;
  ultdiam        := pag_cal.g_ult_dia_mes;

  v_mone_local   := pag_gen.fu_obt_mon_local;
  v_mone_fuerte  := pag_gen.fu_obt_mon_fuerte;
  v_cotiz_fuerte := pag_gen.fu_obt_cotizacion(v_mone_fuerte,v_fec_sist);
  v_proceso      := p_proceso;
  --- La primera vez se utiliza para la apertura del cursor, para saber
  --- hasta que fecha debe devengar por si existan devengados adelantados
  IF P_PROCESO = 'I' THEN --- LLAMADO DESDE UN INICIO DE DIA
    --- para devengar sabados,domingos,feriados
    v_fec_fin := v_fec_sist - 1;
  ELSIF P_PROCESO = 'F' THEN --- LLAMADO DESDE UN CIERRE DE DIA
    IF v_fec_sist = ulthabm THEN
      v_fec_fin := ultdiam;
    ELSE
      v_fec_fin := v_fec_sist;
    END IF;
  END IF;

  FOR reg in c_documentos LOOP
    v_nro_cuenta    := reg.nro_cuenta;
    v_estado        := reg.estado;
    v_moneda        := reg.cod_moneda;
    v_fec_ult_dev   := reg.fec_ult_devengado;
    IF P_PROCESO = 'I' THEN --- LLAMADO DESDE UN INICIO DE DIA
         --- para devengar sabados,domingos,feriados
         v_fec_fin := v_fec_sist - 1;
    ELSIF P_PROCESO = 'F' THEN --- LLAMADO DESDE UN CIERRE DE DIA
      IF v_fec_sist = ulthabm THEN
        v_fec_fin := ultdiam;
      ELSE
        v_fec_fin := v_fec_sist;
      END IF;
    END IF;
    v_redondeo  := 0;
    IF v_moneda != v_mone_local THEN
      if v_moneda = v_mone_fuerte then
        v_cotizacion := v_cotiz_fuerte;
      else
        v_cotizacion := pag_gen.fu_obt_cotizacion(v_moneda,v_fec_sist);
      end if;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo, reg.cod_modalidad, reg.cod_moneda, reg.cod_oficina);
    END IF;
    --
    v_dev_acumulado := reg.dev_acumulado;
    v_fec_ini_dev := nvl(reg.fec_ult_devengado,reg.fec_inicio);
    --
    IF reg.fec_ult_devengado  IS NULL THEN
      v_fec_ini := reg.fec_inicio;
      v_fec_ult_dev := reg.fec_inicio;
    ELSIF reg.fec_ult_devengado >= reg.fec_inicio THEN
      v_fec_ini := reg.fec_ult_devengado + 1;
    END IF;

    IF v_fec_fin >= reg.fec_vencimiento and reg.cod_modalidad not in (109,110) THEN --si ya esta vencido o vence hoy el prestamo,se devenga hasta el vto
       v_fec_fin := reg.fec_vencimiento - 1;
    END IF;
    v_tasa := reg.val_tasa;
    --- Inicializar variables de calculo
    v_interes        := 0;
    v_dev_no_cobrado := 0;
    v_dev_suspenso   := 0;
    v_mto_ajuste     := 0;
    v_fec_fin_dev    := v_fec_fin;

    --- Recuperar capital segun el tipo de documento
    if reg.tip_calculo = 'A' then
      v_capital := nvl(reg.monto,0);--- + nvl(reg.mto_interes,0) ;
    else
      If reg.fec_vencimiento > v_fec_ini_dev And reg.estado <> 'N' Then
        v_capital := nvl(reg.val_presente,0);
      End If;
    end if;

    if reg.cod_modalidad in (109,110) then--Es VISTA y no tiene vencimiento
      v_dia_devengado   := v_fec_fin_dev - v_fec_ini + 1;
    else
      if reg.fec_vencimiento < v_fec_fin_dev + 1 then
        v_fec_fin_dev := reg.fec_vencimiento - 1; --- Hasta el vencimiento de la cuota
      end if;
      v_dia_devengado   := v_fec_fin_dev - v_fec_ini + 1;
    end if;

    if reg.cod_modalidad = 109 then
      v_interes := round(reg.sal_capital * reg.val_tasa * v_dia_devengado / (reg.dia_ano * 100),v_redondeo);
      update md_cta_documentos
      set dev_acumulado     = nvl(dev_acumulado,0)    + nvl(v_interes,0),
      fec_ult_devengado = v_fec_fin,
      sal_val_presente  = nvl(sal_val_presente,0) + nvl(v_interes,0),
      sal_interes = sal_interes+v_interes
      where nro_cuenta = reg.nro_cuenta;
    elsif reg.cod_modalidad = 110 then
      v_interes := round(reg.sal_capital * reg.val_tasa * v_dia_devengado / (reg.dia_ano * 100),v_redondeo);
      update md_cta_documentos
      set dev_acumulado = nvl(dev_acumulado,0)    + nvl(v_interes,0),
      fec_ult_devengado = v_fec_fin,
      sal_interes = sal_interes+v_interes
      where nro_cuenta  = reg.nro_cuenta;
    elsif reg.cod_modalidad = 116 then
      v_interes := round(reg.sal_capital * reg.val_tasa * v_dia_devengado / (reg.dia_ano * 100),v_redondeo);
      --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
      if reg.fec_vencimiento = v_fec_fin_dev + 1  then
        if (nvl(v_interes,0) + nvl(v_dev_acumulado,0) <>
        nvl(reg.mto_interes,0) and
        nvl(reg.tot_int_descontado,0)=0) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
        end if;

        if (nvl(reg.tot_int_descontado,0) > 0 and
        nvl(v_interes,0) + nvl(v_dev_acumulado,0) <> nvl(reg.mto_interes,0)-nvl(reg.tot_int_descontado,0)) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := nvl(reg.sal_interes,0);
        end if;
      end if;

      update md_cta_documentos
      set dev_acumulado = nvl(dev_acumulado,0) + nvl(v_interes,0),
      fec_ult_devengado = v_fec_fin,
      val_int_devengar  = nvl(val_int_devengar,0) - nvl(v_interes,0)
      where nro_cuenta  = reg.nro_cuenta;
    elsif reg.cod_modalidad in (120,122,123,124) then
      v_interes := 0;
      v_dia_dev_cuota := 0;
      for ct in cuotas loop
        -- veo si se devenga por cuotas
        v_interes := nvl(v_interes,0)+
        round((ct.sal_interes/ct.plazo) *
        lf_obt_dia_devengado(ct.fec_vencimiento-ct.plazo,ct.fec_vencimiento,v_fec_ini,v_fec_fin_dev),v_redondeo);
      end loop;
      if v_interes = 0 then
        v_interes := round(reg.mto_interes / (reg.fec_vencimiento - reg.fec_inicio),v_redondeo) * v_dia_devengado;
      end if;

      --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
      if reg.fec_vencimiento = v_fec_fin_dev + 1  then
        if (nvl(v_interes,0) + nvl(v_dev_acumulado,0) <>
        nvl(reg.mto_interes,0) and
        nvl(reg.tot_int_descontado,0)=0) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
        end if;

        if (nvl(reg.tot_int_descontado,0) > 0 and
        nvl(v_interes,0) + nvl(v_dev_acumulado,0) <> nvl(reg.mto_interes,0)-nvl(reg.tot_int_descontado,0)) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := nvl(reg.sal_interes,0);
        end if;
      end if;

      --- Verificar que no quede en negativo el val_int_devengar
      if nvl(reg.mto_interes,0) < (nvl(v_dev_acumulado,0) + nvl(v_interes,0)) then
        v_mto_ajuste := v_interes;
        v_interes :=  (nvl(reg.mto_interes,0))- nvl(v_dev_acumulado,0);
        v_mto_ajuste := v_mto_ajuste - v_interes;
      end if;

      begin
        update md_cta_documentos
        set val_int_devengar  = nvl(val_int_devengar,0) - nvl(v_interes,0),
        dev_acumulado     = nvl(dev_acumulado,0)    + nvl(v_interes,0),
        fec_ult_devengado = v_fec_fin
        where nro_cuenta = reg.nro_cuenta;
      exception
      when others then
        raise_application_error(-20000,sqlerrm);
      end;
    else
      v_interes := 0;
      v_dia_dev_cuota := 0;
      for ct in cuotas loop
        -- veo si se devenga por cuotas
        v_interes := nvl(v_interes,0)+
        round((ct.sal_interes/ct.plazo) *
        lf_obt_dia_devengado(ct.fec_vencimiento-ct.plazo,ct.fec_vencimiento,v_fec_ini,v_fec_fin_dev),v_redondeo);
      end loop;
      if v_interes = 0 then
        v_interes := round(reg.mto_interes / (reg.fec_vencimiento - reg.fec_inicio),v_redondeo) * v_dia_devengado;
      end if;

      --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
      if reg.fec_vencimiento = v_fec_fin_dev + 1  then
        if (nvl(v_interes,0) + nvl(v_dev_acumulado,0) <>
        nvl(reg.mto_interes,0) and
        nvl(reg.tot_int_descontado,0)=0) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
        end if;

        if (nvl(reg.tot_int_descontado,0) > 0 and
        nvl(v_interes,0) + nvl(v_dev_acumulado,0) <> nvl(reg.mto_interes,0)-nvl(reg.tot_int_descontado,0)) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := nvl(reg.sal_interes,0);
        end if;
      end if;

      --- Verificar que no quede en negativo el val_int_devengar
      if nvl(reg.mto_interes,0) < (nvl(v_dev_acumulado,0) + nvl(v_interes,0)) then
        v_mto_ajuste := v_interes;
        v_interes :=  (nvl(reg.mto_interes,0))- nvl(v_dev_acumulado,0);
        v_mto_ajuste := v_mto_ajuste - v_interes;
      end if;

      --- Actualizar maestro del documento
      --- Si debe modificar la fecha de ultimo devengado porque intento hacer devengado aunque puede que la
      --- documento ya halla devengado todo y no hubo montos en ese dia.
      if reg.cod_modalidad = 112 then
        update md_cta_documentos
        set val_int_devengar  = nvl(val_int_devengar,0) - nvl(v_interes,0),
        dev_acumulado     = nvl(dev_acumulado,0)    + nvl(v_interes,0),
        fec_ult_devengado = v_fec_fin
        where nro_cuenta = reg.nro_cuenta;
      else
        update md_cta_documentos
        set val_int_devengar  = nvl(val_int_devengar,0) - nvl(v_interes,0),
        dev_acumulado     = nvl(dev_acumulado,0)    + nvl(v_interes,0),
        fec_ult_devengado = v_fec_fin,
        sal_val_presente  = nvl(sal_val_presente,0) + nvl(v_interes,0)
        where nro_cuenta = reg.nro_cuenta;
      end if;
    end if;

      --- Insertar devengados
      r_deven.nro_cuenta        := v_nro_cuenta;
      r_deven.fecha             := v_fec_sist;
      r_deven.fec_inicio        := v_fec_ini_dev;
      r_deven.fec_ult_devengado := v_fec_fin_dev;
      r_deven.cod_moneda        := reg.cod_moneda;
      r_deven.estado            := reg.estado;
      --r_deven.capital           := nvl(v_capital,0);
      r_deven.capital           := nvl(reg.monto,0);
      r_deven.val_tasa          := reg.val_tasa;
      r_deven.can_dia_interes   := nvl(v_dia_devengado,0);
      r_deven.mto_dev_actual    := v_interes;
      r_deven.mto_ajuste        := v_mto_ajuste;
      r_deven.mto_dev_acumulado := v_interes;
      --- Para casos en que no exista el registro y sea la primera vez
      r_deven.mto_dev_anterior  := v_dev_acumulado;
      pr_ins_md_devengados;
 END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM);
      end if;
END;

/* Proceso de devengado en el momento de la venta del documeento */
PROCEDURE PR_PRO_DEV_VTA_DOC
 (P_NRO_CUENTA IN MD_CTA_DOCUMENTOS.NRO_CUENTA%TYPE
 ,P_FEC_HASTA IN DATE
 ,P_HORA IN VARCHAR2
 ,P_MTO_COBRO IN MD_CTA_DOCUMENTOS.MONTO%TYPE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 )
 IS
   V_MONE_LOCAL     BA_MONEDAS.COD_MONEDA%TYPE;
   V_INTERES        md_cta_documentos.sal_val_presente%TYPE;
   V_CAPITAL        md_cta_documentos.sal_val_presente%TYPE;
   V_FEC_FIN        DATE;
   v_redondeo       number(1);
   v_plz_letra_ant  number(5);
   v_plz_letra_act  number(5);
   v_val_pre_ant    md_cta_documentos.sal_val_presente%type;
   v_val_pre_act    md_cta_documentos.sal_val_presente%type;
   ----
   v_dia_devengado  md_devengados.can_dia_interes%type;
   v_fec_ini        DATE;
   ultdiam           date;
   ulthabm           date;
   v_fec_fin_dev     pr_devengados.fec_inicio%type;
   v_devengo        varchar2(1);
   reg              md_cta_documentos%rowtype;
   v_fec_ini_dev    md_cta_documentos.fec_inicio%type;
   v_int_diario     md_cta_documentos.mto_interes%type;
BEGIN
   PAG_CAL.PR_OBT_DAT_CALENDAR(10);
   if nvl(p_mto_cobro,0) <= 0 then
      return;
   end if;
   v_fec_sist   := p_fec_hasta;
   ultdiam        := PAG_CAL.G_ULT_DIA_MES;
   ulthabm        := PAG_CAL.G_ULT_DIA_MES_HABIL;
   v_horamovim  := p_hora;
   v_mone_local := PAG_GEN.FU_OBT_MON_LOCAL;
   v_secuencia  := nvl(p_nro_secuencia,0);
   --- Recupera datos del documento
   Begin
      select p.*
        into reg
        from md_cta_documentos p
       where nro_cuenta = p_nro_cuenta;
   exception
      when no_data_found then
         raise_application_error(-20000,
         'Cuenta '||p_nro_cuenta||' no registrada');
   End;
   v_estado        := reg.estado;
   v_moneda        := reg.cod_moneda;
   v_redondeo := 0;

   If v_moneda != v_mone_local then
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo, reg.cod_modalidad, reg.cod_moneda, reg.cod_oficina);
   End if;

   v_fec_ini_dev := nvl(reg.fec_ult_devengado,reg.fec_inicio);

   --- Recuperar capital segun el tipo de prestamo
   if reg.tip_calculo = 'A' then
      v_capital :=  nvl(reg.monto,0);---nvl(reg.val_presente,0) + nvl(reg.mto_interes,0) ;
   else
     If reg.fec_vencimiento > v_fec_ini_dev And reg.estado <> 'N' Then
       v_capital := nvl(reg.val_presente,0);
     End If;
   end if;
   v_interes    := 0;
   v_devengo    := 'N';
   If v_fec_sist = ulthabm THEN
     v_fec_fin := ultdiam;
   Else
     v_fec_fin := v_fec_sist;
   End If;
   If reg.fec_ult_devengado  IS NULL THEN
     v_fec_ini := reg.fec_inicio;
   Elsif reg.fec_ult_devengado >= reg.fec_inicio THEN
     v_fec_ini := reg.fec_ult_devengado + 1;
   End If;
   IF v_fec_fin >= reg.fec_vencimiento THEN --si ya esta vencido o vence hoy el prestamo,se devenga hasta el vto
     v_fec_fin := reg.fec_vencimiento - 1;
   END IF;
   v_fec_fin_dev    := v_fec_fin;
   if reg.fec_vencimiento < v_fec_fin_dev + 1 then
     v_fec_fin_dev := reg.fec_vencimiento - 1; --- Hasta el vencimiento de la cuota
   end if;
   --- Verificar si cancela o no el documento
   if nvl(reg.sal_interes,0) <= nvl(p_mto_cobro,0) then
      --- Cancela el interes del documento
      if nvl(reg.dev_acumulado,0) <> nvl(reg.sal_interes,0) then
         --- Verificar si debe devengarse el documento
         v_interes := nvl(reg.sal_interes,0) - nvl(reg.dev_acumulado,0);
      end if;
      v_fec_ult_devengado := reg.fec_vencimiento - 1;
      v_dia_devengado   := v_fec_fin_dev - v_fec_ini + 1;

      if v_interes <> 0 then
        r_deven.nro_cuenta        := p_nro_cuenta;
        r_deven.fecha             := v_fec_sist;
        r_deven.fec_inicio        := v_fec_ini_dev;
        r_deven.fec_ult_devengado := v_fec_ult_devengado;
        r_deven.cod_moneda        := reg.cod_moneda;
        r_deven.estado            := reg.estado;
        --r_deven.capital           := v_capital;
      r_deven.capital           := nvl(reg.monto,0);
        r_deven.val_tasa          := reg.val_tasa;
        r_deven.can_dia_interes   := nvl(v_dia_devengado,0);
        r_deven.mto_dev_actual    := v_interes;
        r_deven.mto_dev_acumulado := v_interes;
        pr_ins_md_devengados;
        v_devengo := 'S';
      end if;
   else --- Si no cancela el documento
      --- Se debe verificar si el monto cobrado corresponde a la fecha
      --- hacer por regla de tres simple
      --- Calcular Interes devengado correspondiente a un dia
      --- Letras de Regulacion Monetaria es diferente el calculo
      if reg.cod_modalidad in (109,110) then -- call money
        v_int_diario := round(reg.monto * reg.val_tasa * 1 / (reg.dia_ano * 100),v_redondeo);
      else
        v_int_diario := round(reg.mto_interes / (reg.fec_vencimiento - reg.fec_inicio),v_redondeo);

      end if;
      if nvl(p_mto_cobro,0) > nvl(reg.dev_acumulado,0) then
        v_interes := nvl(p_mto_cobro,0) - nvl(reg.dev_acumulado,0);
        --- Calcular fecha de ultimo devengado
        If v_int_diario > 0 Then
          v_fec_ult_devengado := nvl(reg.fec_ult_devengado,reg.fec_inicio) + (floor(nvl(v_interes,0)/nvl(v_int_diario,0)));
          v_devengo := 'S';
        End If;
        v_dia_devengado   := v_fec_fin_dev - v_fec_ini + 1;
        --- Insertar devengados
        r_deven.nro_cuenta        := p_nro_cuenta;
        r_deven.fecha             := v_fec_sist;
        r_deven.fec_inicio        := v_fec_ini_dev;
        r_deven.fec_ult_devengado := v_fec_ult_devengado;
        r_deven.cod_moneda        := reg.cod_moneda;
        r_deven.estado            := reg.estado;
        r_deven.capital           := v_capital;
        r_deven.val_tasa          := reg.val_tasa;
        r_deven.can_dia_interes   := nvl(v_dia_devengado,0);
        r_deven.mto_dev_actual    := v_interes;
        r_deven.mto_dev_acumulado := v_interes;
        pr_ins_md_devengados;
        v_devengo := 'S';
      end if;
   end if;

   --- Actualizar maestro del documento
   v_fec_fin := v_fec_ult_devengado;

   if v_devengo = 'S' then
     -- Solo si devengo debe actualizar.
     update md_cta_documentos
        set dev_acumulado     = nvl(dev_acumulado,0) + nvl(v_interes,0),
            val_int_devengar  = nvl(val_int_devengar,0) - nvl(v_interes,0),
            fec_ult_devengado = nvl(v_fec_fin, fec_ult_devengado)
      where nro_cuenta = p_nro_cuenta;
   End If;

   p_nro_secuencia := v_secuencia;
EXCEPTION
    WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||' Dev. en Cobro') ;
      end if;
END;

end PAM_DEV_TMP;
/

