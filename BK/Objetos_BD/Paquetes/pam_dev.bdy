CREATE OR REPLACE PACKAGE BODY IT.PAM_DEV is

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
 v_can_dia_interes  md_devengados.can_dia_interes%Type;
 v_can_dia_anterior md_devengados.can_dia_anterior%Type;
Begin
  IF r_deven.estado = 'C' THEN 
     select rowid 
       into v_rowid
       from md_devengados
      where nro_cuenta = r_deven.nro_cuenta
        and cod_moneda = r_deven.cod_moneda
        and estado     = r_deven.estado
       --- and capital    = r_deven.capital ---CNFREINT-1 - REPO INTERBANCARIO
        and val_tasa   = r_deven.val_tasa
        and usu_insercion <> 'BBVA'; -- REPO: para no duplicar devengados migrados
        
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
                     fec_ult_devengado = r_deven.fec_ult_devengado,
                     capital           = nvl(r_deven.capital,0)
               where nro_cuenta = r_deven.nro_cuenta
                 and cod_moneda = r_deven.cod_moneda
                 and estado     = r_deven.estado
                 and val_tasa   = r_deven.val_tasa
                 and usu_insercion <> 'BBVA';
       else
          --- Existio un feriado o fin de semana y debe acumular
          --- para asentar todo el dia habil en el cierre
          update md_devengados
             set can_dia_interes   = nvl(can_dia_interes,0) + r_deven.can_dia_interes,
                 mto_dev_actual    = nvl(mto_dev_actual,0) + nvl(r_deven.mto_dev_actual,0),
                 mto_ajuste        = nvl(mto_ajuste,0) + nvl(r_deven.mto_ajuste,0),
                 mto_dev_acumulado = nvl(mto_dev_acumulado,0) + nvl(r_deven.mto_dev_actual,0),
                 fecha             = r_deven.fecha,
                 fec_ult_devengado = r_deven.fec_ult_devengado,
                 capital           = nvl(r_deven.capital,0)
           where nro_cuenta = r_deven.nro_cuenta
             and cod_moneda = r_deven.cod_moneda
             and estado     = r_deven.estado
             and val_tasa   = r_deven.val_tasa
             and usu_insercion <> 'BBVA';
       end if;  
        
   ELSE ---CNFREINT-1 - REPO INTERBANCARIO
     select rowid 
       into v_rowid
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
     
     -- REPO: si el estado es Ripeado, debe tener la misma cantidad de dias
     --       de interes (actual y anterior) que la cuenta original.
     If r_deven.estado = 'R' Then
        -- Buscamos los dias de interes de la cuenta en estado normal --
        Begin
          select nvl(d.can_dia_interes,0), nvl(d.can_dia_anterior,0) 
            into v_can_dia_interes, v_can_dia_anterior
            from md_devengados d
           where d.nro_cuenta = r_deven.nro_cuenta
             and d.cod_moneda = r_deven.cod_moneda
             and d.estado     = 'C'
             and d.val_tasa   = r_deven.val_tasa
             and usu_insercion <> 'BBVA';
         Exception
           When Others Then
             v_can_dia_interes := 0;
             v_can_dia_anterior := 0;
         End;
         -- Modificamos en la cuenta ripeada --
         update md_devengados
           set can_dia_interes   = v_can_dia_interes,
               can_dia_anterior  = v_can_dia_anterior
         where nro_cuenta = r_deven.nro_cuenta
           and cod_moneda = r_deven.cod_moneda
           and estado     = r_deven.estado
           and capital    = r_deven.capital  
           and val_tasa   = r_deven.val_tasa;
     End If;    
        
   END IF;

exception
   when no_data_found then
      if r_deven.estado = 'R' Then
        Begin
          select nvl(d.can_dia_interes,0), nvl(d.can_dia_anterior,0) 
            into v_can_dia_interes, v_can_dia_anterior
            from md_devengados d
           where d.nro_cuenta = r_deven.nro_cuenta
             and d.cod_moneda = r_deven.cod_moneda
             and d.estado     = 'C'
             and d.val_tasa   = r_deven.val_tasa
             and usu_insercion <> 'BBVA';
         Exception
           When Others Then
             v_can_dia_interes := 0;
             v_can_dia_anterior := 0;
         End;
	    end if;
      insert into md_devengados(
         nro_cuenta,fecha,fec_inicio, fec_ult_devengado, cod_moneda,
         estado, capital, val_tasa,can_dia_interes, mto_dev_anterior, can_dia_anterior,
         mto_dev_actual, mto_ajuste, mto_dev_acumulado)
      values
        (r_deven.nro_cuenta, r_deven.fecha,r_deven.fec_inicio, r_deven.fec_ult_devengado,
         r_deven.cod_moneda, r_deven.estado, r_deven.capital, r_deven.val_tasa,
         DECODE(r_deven.estado,'R',v_can_dia_interes, NVL(r_deven.can_dia_interes,0)), 
         DECODE(r_deven.estado,'R',0,nvl(r_deven.mto_dev_anterior,0)), 
         DECODE(r_deven.estado,'R',v_can_dia_anterior, nvl(r_deven.can_dia_anterior,0)),
         r_deven.mto_dev_actual, r_deven.mto_ajuste,
         DECODE(r_deven.estado,'R',0,nvl(r_deven.mto_dev_anterior,0))+nvl(r_deven.mto_dev_acumulado,0));
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
 (P_PROCESO IN VARCHAR2)
 IS
   v_mone_local      ba_monedas.cod_moneda%type;
   v_mone_fuerte     ba_monedas.cod_moneda%type;
   v_cotizacion      ge_cotizaciones.val_conversion%type;
   v_interes         pr_cuotas.mto_interes%type;
   v_capital         pr_cuotas.mto_capital%type;
   v_tasa            md_cta_documentos.val_tasa%type;
   v_nro_cuenta      pr_cta_prestamos.nro_cuenta%type;
   v_cotiz_fuerte    ge_cotizaciones.val_venta%type;
   v_dev_acumulado   md_devengados.mto_dev_acumulado%type;
   v_dia_devengado   md_devengados.can_dia_interes%type;
   v_dev_suspenso    pr_cuotas.dev_suspenso%type;
   v_dev_no_cobrado  pr_cuotas.dev_no_cobrado%type;
   v_mto_ajuste      pr_devengados.mto_ajuste%type;
   v_fec_ini_dev     pr_devengados.fec_inicio%type;
   v_fec_fin_dev     pr_devengados.fec_inicio%type;
   v_dia_dev_cuota   number;
   v_redondeo        number(1);
   v_fec_ini         date;
   v_fec_fin         date;
   v_fec_ult_dev     date;
   ulthabm           date;
   ultdiam           date;
   v_existe          varchar2(1);
   --- Definicion del cursor de documentos vigentes a procesar
   cursor c_documentos IS
   SELECT distinct a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.monto,
          a.val_int_devengar, val_tasa, fec_inicio, fec_vencimiento, o.estado,
          sal_interes, cod_moneda, NVL(fec_ult_devengado, NULL) fec_ult_devengado,
          c.cod_gru_economico, fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
          tip_calculo, a.val_presente,a.sal_val_presente, a.mto_interes, a.dev_acumulado,
          a.dia_ano, a.tot_int_descontado, a.sal_capital, NVL(a.sal_disponible,0) sal_disponible, o.nro_cuota, o.nro_cta_repo, 
          a.fec_cam_estado,NVL(a.mer_secundario, 'N') mer_secundario --DYDMR-4180 --mer_secundario >> mer_secundario FIELDESK-158692 - Error devengamiento Prestamos Financieros AFD y Bonos Financieros
     FROM ge_clientes c, ge_cta_clientes b, md_cta_documentos a, md_cuo_instrumentos o
    WHERE c.cod_persona = b.cod_persona
      and b.nro_cuenta  = a.nro_cuenta
      and a.nro_cuenta = o.nro_cuenta
      and b.relacion    = 'P'
      and instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||a.cod_modalidad||',')=0
      and (o.estado not in ('S','N') or (a.estado = 'N' and a.fec_cam_estado = v_fec_sist))--- No incluir Canceladas--DYDMR-4180
      and a.cod_modalidad not in (113, 138, 139, 140) --113 crédito tributario / 138 FLI / 139 REPO ON / 140 REPO TRIPARTITO: no devengan
      --- Que no tome cuentas vencidas aunque no halla devengado todo
      and (a.cod_modalidad in (105,109,110) -- Desarrollo Interno del banco
       or FUM_OBT_OPE_REPO(a.cod_modulo,a.cod_modalidad,'S') = 'S' -- Repo Fase II / 04-2016
       or a.fec_vencimiento > decode(v_fec_sist,v_fec_fin,v_fec_sist,(v_fec_fin - 1))
       or (a.fec_vencimiento > a.fec_ult_devengado and a.val_int_devengar <> 0)) -- JIRA-1080
      --- No debe devengar las cuentas canceladas por adelantado
      and nvl(a.fec_ult_devengado,a.fec_inicio-1) < v_fec_fin
      and a.fec_inicio <= v_fec_sist
      and (nvl(a.sal_interes,0) > 0 or (a.estado = 'N' and a.fec_cam_estado = v_fec_sist) or a.cod_modalidad in (109,110) or FUM_OBT_OPE_REPO(a.cod_modulo,a.cod_modalidad,'S') = 'S') -- CNFREINT-104 --DYDMR-4180
      --- Cuando devenga de mas tambien debe incluir
      and (nvl(dev_acumulado,0) <> nvl(a.mto_interes,0) or a.cod_modalidad in (109,110) or FUM_OBT_OPE_REPO(a.cod_modulo,a.cod_modalidad,'S') = 'S')
      
      union

      SELECT distinct a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.monto,
                a.val_int_devengar, val_tasa, fec_inicio, fec_vencimiento, o.estado,
                sal_interes, cod_moneda, NVL(fec_ult_devengado, NULL) fec_ult_devengado,
                c.cod_gru_economico, fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
                tip_calculo, a.val_presente,a.sal_val_presente, a.mto_interes, a.dev_acumulado,
                a.dia_ano, a.tot_int_descontado, a.sal_capital, NVL(a.sal_disponible,0) sal_disponible, o.nro_cuota, null nro_cta_repo, 
                a.fec_cam_estado,NVL(a.mer_secundario, 'N') mer_secundario --DYDMR-4180 --mer_secundario >> mer_secundario FIELDESK-158692 - Error devengamiento Prestamos Financieros AFD y Bonos Financieros
           FROM ge_clientes c, ge_cta_clientes b, md_cta_documentos a, md_cuo_instrumentos o
          WHERE c.cod_persona = b.cod_persona
            and b.nro_cuenta  = a.nro_cuenta
            and a.nro_cuenta = o.nro_cuenta
            and b.relacion    = 'P'
            and ((o.estado in ('T','C'))or (a.estado = 'N' and a.fec_cam_estado = v_fec_sist))--- Solo incluir el detalle del bono
            and instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||a.cod_modalidad||',')>0
            --- No debe devengar las cuentas canceladas por adelantado
            and nvl(a.fec_ult_devengado,a.fec_inicio-1) < v_fec_fin
            and a.fec_inicio <= v_fec_sist
            and (nvl(a.sal_interes,0) > 0 or (a.estado = 'N' and a.fec_cam_estado = v_fec_sist))
            -- Order By a.nro_cuenta, o.estado, o.nro_cuota, o.nro_cta_repo Asc
          Order By 4, 10, 25,26 Asc;

    cursor cuotas is
        select  nro_cuota, mto_interes, sal_interes, fec_vencimiento,plazo, dev_acumulado,
        mto_int_descontado, estado
          from md_doc_detalles
         where nro_cuenta = v_nro_cuenta
           and (estado != 'N' or(fec_ult_pago < fec_vencimiento) )
           and ((fec_vencimiento > V_FEC_FIN
           and fec_vencimiento - plazo  <= v_fec_sist) or estado = 'N' and fec_vencimiento >= V_FEC_FIN)
           and nvl(dev_acumulado,0) < mto_interes;
           
    cursor mer_secundario is
           select 'I' tip_devegado, md.nro_cuenta,sum(md.plazo),
            round(sum(md.dev_acumulado) /sum(md.plazo),2) dev_diario
            from  md_doc_detalles md, md_cta_documentos mc
            where mc.nro_cuenta = md.nro_cuenta
            and mc.nro_cuenta = v_nro_cuenta
            group by md.nro_cuenta
            union
           select 'C' tip_devegado,md.nro_cuenta,sum(md.plazo),
            round( (sum(md.mto_capital)-(sum(md.dev_acumulado)+sum(md.val_cap_presente) ) +(sum(md.mto_interes) -sum(md.dev_acumulado))) /sum(md.plazo),2)
            from  md_doc_detalles md, md_cta_documentos mc
            where mc.nro_cuenta = md.nro_cuenta
            and mc.nro_cuenta = v_nro_cuenta
            group by md.nro_cuenta;
            
procedure lp_obt_mto_devengar(p_nro_cuenta         in md_cuo_instrumentos.nro_cuenta%type, 
                              p_est_cuota          in md_cuo_instrumentos.estado%type,
                              p_nro_cuota          in md_cuo_instrumentos.nro_cuota%type,
                              p_sal_disponible     in md_cta_documentos.sal_disponible%type,         
                              p_monto              in out md_cta_documentos.monto%type, 
                              p_val_int_devengar   in out md_cta_documentos.val_int_devengar%type,  
                              p_sal_interes        in out md_cta_documentos.sal_interes%type,
                              p_val_presente       in out md_cta_documentos.val_presente%type, 
                              p_sal_val_presente   in out md_cta_documentos.sal_val_presente%type, 
                              p_mto_interes        in out md_cta_documentos.mto_interes%type,
                              p_dev_acumulado      in out md_cta_documentos.dev_acumulado%type, 
                              p_tot_int_descontado in out md_cta_documentos.tot_int_descontado%type, 
                              p_sal_capital        in out md_cta_documentos.sal_capital%type)
                              is
---Procedimiento Interno para calcular los distintos montos que representa cada cuota del documento
---El porcentaje recuperado deberá utilizarse para calcular los distintos montos a calcular  

v_porcentaje     number;
--rg_docu        md_cta_documentos%rowtype;
v_redondeo       number;
v_mto_documento  md_cta_documentos.monto%type;
v_mto_cuota      md_cuo_instrumentos.mto_cuota%type;
v_cod_modulo     md_cta_documentos.cod_modulo%type;
v_cod_modalidad   md_cta_documentos.cod_modalidad%type;
v_cod_moneda     md_cta_documentos.cod_moneda%type;
v_cod_oficina     md_cta_documentos.cod_oficina%type;

begin

  select d.monto,d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.cod_oficina, sum(c.mto_cuota)
    into v_mto_documento, v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_mto_cuota
    from md_cta_documentos d, md_cuo_instrumentos c
   where d.nro_cuenta = c.nro_cuenta
     and d.nro_cuenta = p_nro_cuenta
     and c.estado = p_est_cuota
   group by d.monto,d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.cod_oficina;
    
   -- Como un Repo Otorgado tiene los mismos estados que una cuenta normal
   -- el monto a tomar en este tipo de repo es el de la negociacion y no 
   -- el saldo disponible como en los demas casos.    
   If fum_obt_ope_repo(v_cod_modulo,v_cod_modalidad,'S','O') = 'N' And p_est_cuota = 'C' And p_nro_cuota = 1 Then
      v_mto_cuota := p_sal_disponible;
   End If;
      
   v_porcentaje := (v_mto_cuota * 100 / v_mto_documento);
     
   v_redondeo   := fug_obt_pardinamico( 'VAL_RED_MON_EXTRANJERA', 
                                         v_cod_modulo, 
                                         v_cod_modalidad, 
                                         v_cod_moneda, 
                                         v_cod_oficina );

  If v_porcentaje is not null then 
    v_porcentaje := v_porcentaje / 100;

    p_monto               :=   round((p_monto * v_porcentaje),v_redondeo);
    p_val_int_devengar    :=   round(p_val_int_devengar * v_porcentaje,v_redondeo);
    p_sal_interes         :=   round(p_sal_interes * v_porcentaje,v_redondeo);
    p_val_presente        :=   round(p_val_presente * v_porcentaje,v_redondeo);
    p_sal_val_presente    :=   round(p_sal_val_presente * v_porcentaje,v_redondeo);
    p_mto_interes         :=   round(p_mto_interes * v_porcentaje,v_redondeo);
    p_dev_acumulado       :=   round(p_dev_acumulado * v_porcentaje,v_redondeo);
    p_tot_int_descontado  :=   round(p_tot_int_descontado * v_porcentaje,v_redondeo);
    p_sal_capital         :=   round(p_sal_capital * v_porcentaje,v_redondeo);

  End if;
  
exception
  when no_data_found then
    null;
end;    
    
                
BEGIN
  --
  pag_cal.pr_obt_dat_calendar(10);
  v_fec_sist     := pag_cal.g_fec_actual;
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

  FOR reg in c_documentos Loop
    
  ---------------------------------------------------------------------------
  ---Se invoca al proceso que realice el calculo de los montos por porcentaje 
  lp_obt_mto_devengar(reg.nro_cuenta, 
                      reg.estado,
                      reg.nro_cuota,
                      reg.sal_disponible,        
                      reg.monto, 
                      reg.val_int_devengar,  
                      reg.sal_interes,
                      reg.val_presente, 
                      reg.sal_val_presente, 
                      reg.mto_interes,
                      reg.dev_acumulado, 
                      reg.tot_int_descontado, 
                      reg.sal_capital);
   --------------------------------------------------------------------------
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
      v_capital := nvl(reg.monto,0);
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
    elsif reg.cod_modalidad in (116,146) then
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
     
    elsif reg.cod_modalidad in (120,122) then
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
    --- devengamiento de mercado_secundario
     elsif instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||reg.cod_modalidad||',')>0 and reg.mer_secundario = 'S'then
      for ms in Mer_secundario loop
        v_interes := 0;
      v_dia_dev_cuota := 0;
      
      
        
      if reg.cod_moneda = 'GS' then
         v_interes := round(ms.dev_diario * v_dia_devengado);
      else
        v_interes := round(ms.dev_diario * v_dia_devengado,2);
      end if;

      
      if ms.tip_devegado = 'I' then
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
       end if;
      
       --- Insertar devengados
      r_deven.nro_cuenta        := v_nro_cuenta;
      r_deven.fecha             := v_fec_sist;
      r_deven.fec_inicio        := v_fec_ini_dev;
      r_deven.fec_ult_devengado := v_fec_fin_dev;
      r_deven.cod_moneda        := reg.cod_moneda;
      r_deven.estado            := reg.estado;
      r_deven.capital           := nvl(reg.monto,0);
      
      if ms.tip_devegado = 'C' then
         r_deven.val_tasa          := 0;
      else
         r_deven.val_tasa          := reg.val_tasa;
      end if;
      
      if v_interes is not null then
        
      r_deven.can_dia_interes   := nvl(v_dia_devengado,0);
      r_deven.mto_dev_actual    := v_interes;
      r_deven.mto_ajuste        := v_mto_ajuste;
      r_deven.mto_dev_acumulado := v_interes;
      --- Para casos en que no exista el registro y sea la primera vez
      r_deven.mto_dev_anterior  := v_dev_acumulado;
      pr_ins_md_devengados;
      end if;
      
      end loop;
    else
      v_interes := 0;
      v_dia_dev_cuota := 0;
      for ct in cuotas loop
        -- veo si se devenga por cuotas
        --Si la cuota fue pagada antes del vencimiento debe devengar hasta el vencimiento FQ-SPI 3124
        if ct.estado = 'N'  then
           v_fec_fin_dev := ct.fec_vencimiento;
        end if;
        
        v_interes := nvl(v_interes,0)+
        round((ct.mto_interes/ct.plazo) *
        lf_obt_dia_devengado(ct.fec_vencimiento-ct.plazo,ct.fec_vencimiento,v_fec_ini,v_fec_fin_dev),v_redondeo);
        
         if ct.fec_vencimiento = v_fec_fin_dev + 1 then
            if nvl(v_interes,0) + nvl(ct.dev_acumulado,0) <>
               nvl(ct.mto_interes,0) - nvl(ct.mto_int_descontado,0) then
               v_mto_ajuste := v_interes - (nvl(ct.mto_interes,0) - nvl(ct.mto_int_descontado,0) - nvl(ct.dev_acumulado,0));
               v_interes    := (nvl(ct.mto_interes,0) - nvl(ct.mto_int_descontado,0) - nvl(ct.dev_acumulado,0));
            end if;
         end if;
            
         --- Actualizar cuotas
          if ct.estado <> 'N' then  
             update md_doc_detalles
                set dev_acumulado = nvl(dev_acumulado,0) + nvl(v_interes,0) 
              where nro_cuenta = reg.nro_cuenta and
                    nro_cuota = ct.nro_cuota;
          else             
            update md_doc_detalles
               set dev_acumulado = ct.mto_interes 
             where nro_cuenta = reg.nro_cuenta and
                   nro_cuota = ct.nro_cuota;
          end if;
        --SPI 3124
      end loop;
      
      --Verifico que no sea cuentas con cuotas para calcular el interes
      begin
         select distinct 'S'
           into v_existe
           from md_doc_detalles 
          where nro_cuenta = reg.nro_cuenta;
      exception
         when no_data_found then
            v_existe:= 'N';
         when others then
            v_existe:= 'N';
      end;
       
      if nvl(v_interes,0) = 0 and v_existe = 'N' then
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
      
       --- Actualizo registros cuando se Cancela Anticipadamente - DYDMR-4180
      if reg.cod_modalidad in (117,118) and reg.estado = 'N' and reg.fec_cam_estado = v_fec_sist then
        v_interes := reg.val_int_devengar;
      end if;

      --- Actualizar maestro del documento
      --- Si debe modificar la fecha de ultimo devengado porque intento hacer devengado aunque puede que la
      --- documento ya halla devengado todo y no hubo montos en ese dia.
    if v_interes > 0 then
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
    end if;
    
      -- REPO(cnf_rabp_02-2016): Si es cuenta Ripeada(Instrumento bajo un Repo), registramos el devengado del mismo
      If reg.estado = 'R' Then
        Update md_cuo_instrumentos i
           Set i.mto_dev_cuo_actual = nvl(i.mto_dev_cuo_actual,0) + nvl(v_interes,0)
         Where i.nro_cuenta   = reg.nro_cuenta
           And i.nro_cuota    = reg.nro_cuota
           And i.nro_cta_repo = reg.nro_cta_repo;
      End If;
    if instr(fug_obt_pardinamico('COD_MAD_MER_SECUNDARIO'),','||reg.cod_modalidad||',') = 0 and reg.mer_secundario <> 'S'then
      --- Insertar devengados
      r_deven.nro_cuenta        := v_nro_cuenta;
      r_deven.fecha             := v_fec_sist;
      r_deven.fec_inicio        := v_fec_ini_dev;
      r_deven.fec_ult_devengado := v_fec_fin_dev;
      r_deven.cod_moneda        := reg.cod_moneda;
      r_deven.estado            := reg.estado;
      r_deven.capital           := nvl(reg.monto,0);
      r_deven.val_tasa          := reg.val_tasa;
      r_deven.can_dia_interes   := nvl(v_dia_devengado,0);
      r_deven.mto_dev_actual    := v_interes;
      r_deven.mto_ajuste        := v_mto_ajuste;
      r_deven.mto_dev_acumulado := v_interes;
      --- Para casos en que no exista el registro y sea la primera vez
      r_deven.mto_dev_anterior  := v_dev_acumulado;
      pr_ins_md_devengados;
    end if;
 END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001,v_nro_cuenta || '-'|| sqlerrm);
      /*if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM);
      end if;*/
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

end PAM_DEV;
/
