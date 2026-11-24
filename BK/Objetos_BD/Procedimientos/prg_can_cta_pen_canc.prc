create or replace procedure it.PRG_CAN_CTA_PEN_CANC
(p_nro_cuenta  ge_cuentas.nro_cuenta%TYPe default null)
is
--
v_fec_actual date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
v_hor_mov ge_movimientos.hora%type;
--
SC_CARIMP GE_MOVIMIENTOS.MONTO%TYPE:=0;
SC_DIFEREN GE_MOVIMIENTOS.MONTO%TYPE:=0;

sc_cdofici ba_oficinas.cod_oficina%type;
sc_cdmoned ba_monedas.cod_moneda%type;
SC_TIE_BLOQUEO varchar2(1);
sc_cdmodul ge_modalidades.cod_modulo%type;
sc_cdmodal ge_modalidades.cod_modalidad%type;
v_lugar  varchar2(3000);

MONTCAR GE_MOVIMIENTOS.MONTO%TYPE:=0;
sc_impuest GE_MOVIMIENTOS.MONTO%TYPE:=0;
v_secuencia number(3);
v_nro_sec number(3);
--
cdtasca GE_MOVIMIENTOS.MONTO%TYPE:=0;
vltasca GE_MOVIMIENTOS.MONTO%TYPE:=0;
cdtasim GE_MOVIMIENTOS.MONTO%TYPE:=0;
vltasim GE_MOVIMIENTOS.MONTO%TYPE:=0;
--
v_sal_dev_acu GE_MOVIMIENTOS.MONTO%TYPE:=0;
--
v_capital ge_movimientos.monto%type:=0;  --Capital
v_sal_cap_cc ge_movimientos.monto%type:=0;  --Capital Cta.Cte
v_interes ge_movimientos.monto%type:=0;  --Interes a Pagar
v_cap_acre ge_movimientos.monto%type:=0;  --Capital acreedor
v_cap_deu ge_movimientos.monto%type:=0;  --Capital acreedor
v_prev_sob ge_movimientos.monto%type:=0;  --Previsiones sobregiro
v_prev_con ge_movimientos.monto%type:=0;  --Previsiones sobregiro
v_lin_sob ge_movimientos.monto%type:=0;   --Linea de Sobregiro
v_mto_embargo ge_movimientos.monto%type:=0;   --Monto Embargo Judicial
v_nro_sec_sobregiro   number(8);
v_nro_linea   number(8);
v_est_modulo         ba_modulos.estado%TYPE;
v_horario            VARCHAR2(1) := 'D';
------Datos a ser definidos
-- 348 DEPURACION
SC_NMCAUSA VARCHAR2(100):= 'DEPURACION DE DATOS'; --Para Cancelacion
SC_CDCAUSA VARCHAR2(100):= 388; --'348' Para Cancelacion

SC_COBRCAR varchar2(1):='N';
v_cod_usuario varchar2(100):= upper(user); --Definir con que usuario se va a realizar
--777 DEPURACION  -> GE_CAUSALES
v_det_causal varchar2(100):= 'DEPURACION'; --Para Inhibicion
-- GEN_MOV_Dep. (Generar Movimientos de Dep.ración)
v_gen_mov_MIG varchar2(100):= nvl(fug_obt_pardinamico('GEN_MOV_MIG', NULL, NULL, null),'N');
v_fec_fin date:= '01/01/2041';
v_origen varchar2(300):='DEPURACION GNB';
v_nro_cuenta_can varchar2(100);
v_nocturno varchar2(1):=null;
v_can_prev_sob number(10);
v_sal_total number(18);
v_fec_fin_de_mes date;
v_sal_cta number(18,2);
v_sal_ret number(18,2);
V_MTO_CRE_PENDIENTES number(18,2);
V_MTO_DEB_PENDIENTES number(18,2);
V_MTO_CRE_A_CONFIRMAR number(18,2);
--RG_MOVS PAG_CTA.RG_MOVS;

--cursor de datos de cuentas con saldo
  cursor cur_cta_con_sal is
     select a.*
        from GE_DAT_CANCELACION a, ge_cuentas b
           where a.nro_cuenta= nvl(p_nro_cuenta, a.nro_cuenta)
              and a.nro_cuenta= b.nro_cuenta
              and a.estado=b.estado -- Solo si siguen en el mismo estado se cancela
              and nvl(a.procesado,'N')='N';

-- Genera Movimientos
PROCEDURE LP_GENERA_MOVIMIENTOS (ww_fcvalor in date,
                          ww_cdmodul in number,
                          ww_cdmodal in number,
                          ww_cdofici in number,
                          ww_nrcuent in varchar2,
                          ww_cdtranp in number,
                          ww_cdtrans in number,
                          ww_imtrans in number,
                          ww_nrdocum in number,
                          ww_cdcausa in number,
                          ww_emaviso in VARCHAR2,
                          ww_cdtasas in number,
                          ww_imtasas in number,
                          ww_esctaol in varchar2,
                          ww_cnmovim in varchar2,
                          ww_rubro in number,
                          ww_cotizacion in number,
                          ww_mto_equ_local in number) IS

r_gmovi ge_movimientos%rowtype;
v_cod_ofi_origen ba_oficinas.cod_oficina%type;

BEGIN
   v_lugar := 'LP_GENERA_MOVIMIENTOS';
  v_secuencia := nvl(v_secuencia, 0) + 1;
   --Toma el Codigo de la  Oficina Origen
   select DECODE(ww_cdtranp,325,ww_cdofici,TO_NUMBER(sc_cdofici))
   into v_cod_ofi_origen
   from dual;


   --Prepara el registro para insertar en GE_MOVIMIENTOS
   r_gmovi.cod_usuario     := v_cod_usuario;
   r_gmovi.hora            := v_hor_mov;
   r_gmovi.nro_secuencia   := nvl(v_secuencia, 0);
   r_gmovi.cod_modulo      := ww_cdmodul;
   r_gmovi.cod_modalidad   := ww_cdmodal;
   r_gmovi.cod_oficina     := ww_cdofici;
   r_gmovi.nro_cuenta      := ww_nrcuent;
   r_gmovi.cod_moneda      := SC_CDMONED;
   r_gmovi.fec_valor       := v_fec_actual;
   r_gmovi.fecha           := v_fec_actual;
   r_gmovi.cod_tra_padre   := ww_cdtranp;
   r_gmovi.cod_transaccion := ww_cdtrans;
   r_gmovi.est_cuenta      := ww_esctaol;
   r_gmovi.estado          := 'N';
   r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
   r_gmovi.reversado       := 'N';
   r_gmovi.emi_aviso       := ww_emaviso;
   r_gmovi.protegido       := 'N';
   r_gmovi.cod_mod_padre   := SC_CDMODUL;
   r_gmovi.cod_mad_padre   := SC_CDMODAL;
   r_gmovi.monto           := ww_imtrans;
   r_gmovi.nro_documento   := ww_nrdocum;
   r_gmovi.cod_causa       := ww_cdcausa;
   r_gmovi.cod_tasa        := ww_cdtasas;
   r_gmovi.val_tasa        := ww_imtasas;
   r_gmovi.concepto        := ww_cnmovim;
   r_gmovi.cod_rubro       := ww_rubro;
   r_gmovi.cotizacion      := ww_cotizacion;
   r_gmovi.mto_equ_local   := ww_mto_equ_local;
   --Inserta en GE_MOVIMIENTOS--
   pag_gen.pr_ins_ge_movimiento(r_gmovi,v_nocturno);

   --v_secuencia := nvl(v_secuencia, 1) + 1;
EXCEPTION
  WHEN OTHERS THEN
   raise_application_error(-20000,'En Genera Movimientos '||ww_cdtrans||' sql '||sqlerrm);
END;
--Genera los movimientos finales
PROCEDURE LP_MOVIMIENTOS (v_nro_cuenta in ge_cuentas.nro_cuenta%type) IS
   ww_fcvalor date := v_fec_actual;
   ww_cdmodul ge_movimientos.cod_modulo%type;
   ww_cdmodal ge_movimientos.cod_modalidad%type;
   ww_cdofici ge_movimientos.cod_oficina%type;
   ww_nrcuent ge_movimientos.nro_cuenta%type;
   ww_cdtranp ge_movimientos.cod_tra_padre%type := 301;
   ww_cdtrans ge_movimientos.cod_transaccion%type;
   ww_imtrans ge_movimientos.monto%type;
   ww_nrdocum ge_movimientos.nro_documento%type := null;
   ww_cdcausa ge_movimientos.cod_causa%type := sc_cdcausa;
   ww_emaviso ge_movimientos.emi_aviso%type;
   ww_cdtasas ge_movimientos.cod_tasa%type;
   ww_imtasas ge_movimientos.val_tasa%type;
   ww_esctaol ge_movimientos.est_cuenta%type := null;
   ww_cnmovim ge_movimientos.concepto%type := 'Dep.Can.Cta..';
   ww_montocargo ge_movimientos.monto%type := 0;

BEGIN
  v_secuencia :=nvl(v_secuencia,0)+1;
   V_lugar := 'Movimiento_fgdiari - 1';
   ww_cdmodul := sc_cdmodul;
   ww_cdmodal := sc_cdmodal;
   ww_cdofici := sc_cdofici;
   ww_nrcuent := v_nro_cuenta;
   ww_cdtrans := 501;
   ww_imtrans := montcar;
   ww_emaviso := 'S';
   ww_cdtasas := cdtasca;
   ww_imtasas := vltasca;
   v_lugar := 'Movimiento_fgdiari - 3';
   --- Inicializar transacciones de cambio de estado
      ww_imtrans := null;
      ww_emaviso := 'N';
      ww_cdtasas := null;
      ww_imtasas := null;
   If sc_cdmodul = 4 Then
      If /*(\*sc_forext in ('E', 'G') and*\  nvl(sc_diferen,0) <> 0) or*/ sc_tie_bloqueo = 'S' Then
        --ww_cdtrans := 405;
        --ww_esctaol := 'P';
        --30/08-- Va a ser Cancelado, porque el saldo se va a Dep.rar
        ww_cdtrans := 406;
        ww_esctaol := 'C';
        Update CC_CTA_CORRIENTES
           set --ESTADO = ww_esctaol,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(sc_carimp,0),
               FEC_CAM_ESTADO = v_fec_actual,
               tra_prohibida = 'N',
               cod_cau_cancelacion = SC_CDCAUSA
         where NRO_CUENTA = ww_nrcuent;

        --actualizar el estado con el pag_cta para poder reversar
       pag_cta.pr_set_variables(v_cod_usuario, ww_fcvalor,
                                ww_cdtranp,--cancelación
                                'N',--estado mvto
                                'N',--reversado
                                v_secuencia,
                                ww_esctaol, -- estado
                                ww_cdofici,
                                ww_cdmodul,
                                ww_cdmodal);
       PAG_CTA.PR_ACT_ESTADO(ww_nrcuent,ww_esctaol,ww_fcvalor,v_hor_mov,null,'S');--procesar
       v_secuencia := nvl(v_secuencia, 0) + 1;
       IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
          raise_application_error(-20000,'Act.Est.'||pag_cta.fu_obt_msj_error());

       END IF;
     Else
        ww_cdtrans := 406;
      ww_esctaol := 'C';
        --
        Update CC_CTA_CORRIENTES
           set SAL_TOTAL = nvl(SAL_TOTAL,0) - nvl(sc_diferen,0) - nvl(sc_carimp, 0) - nvl(sc_impuest, 0),
               tra_prohibida = 'N',
               estado=ww_esctaol,
               cod_cau_cancelacion = SC_CDCAUSA,
               FEC_CAM_ESTADO = v_fec_actual
         where NRO_CUENTA = ww_nrcuent;
         --actualizar el estado con el pag_cta para poder reversar
         pag_cta.pr_set_variables(v_cod_usuario,
                                  ww_fcvalor,
                                  ww_cdtranp,--cancelación
                                  'N',--estado mvto
                                  'N',--reversado
                                  v_secuencia,
                                  ww_esctaol, -- estado
                                  ww_cdofici,
                                  ww_cdmodul,
                                  ww_cdmodal);
         PAG_CTA.PR_ACT_ESTADO(ww_nrcuent,ww_esctaol,ww_fcvalor,v_hor_mov,null,'S');--procesar
         v_secuencia := nvl(v_secuencia, 0) + 1;
         IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
            raise_application_error(-20000,'Act.Est.'||pag_cta.fu_obt_msj_error());
         END IF;
     End If;

   ElsIf sc_cdmodal = 31 Then
      If /*(sc_forext in ('E', 'G') and nvl(sc_diferen,0) > 0) or*/ sc_tie_bloqueo = 'S' Then

        ww_cdtrans := 406;
        ww_esctaol := 'C';
        Update AH_CTA_VISTAS
           set SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(sc_carimp,0),
               TRA_PROHIBIDA = 'N',
               cod_cau_cancelacion = SC_CDCAUSA,
               estado=ww_esctaol,
               FEC_CAM_ESTADO = v_fec_actual
         where NRO_CUENTA = ww_nrcuent;
         --actualizar el estado con el pag_cta para poder reversar
         pag_cta.pr_set_variables(v_cod_usuario,
                                  ww_fcvalor,
                                  ww_cdtranp,--cancelación
                                  'N',--estado mvto
                                  'N',--reversado
                                  v_secuencia,
                                  ww_esctaol, -- estado
                                  ww_cdofici,
                                  ww_cdmodul,
                                  ww_cdmodal);
         PAG_CTA.PR_ACT_ESTADO(ww_nrcuent,ww_esctaol,ww_fcvalor,v_hor_mov,null,'S');--procesar
         v_secuencia := nvl(v_secuencia, 0) + 1;
         IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
            raise_application_error(-20000,'Act.Est.'||pag_cta.fu_obt_msj_error());
         END IF;
     Else
        ww_cdtrans := 406;
        ww_esctaol := 'C';
        Update AH_CTA_VISTAS
           set SAL_TOTAL = SAL_TOTAL - nvl(sc_diferen,0) - nvl(sc_carimp,0) - nvl(sc_impuest, 0),
               TRA_PROHIBIDA = 'N',
               cod_cau_cancelacion = SC_CDCAUSA,
               estado=ww_esctaol,
               FEC_CAM_ESTADO = v_fec_actual
         where NRO_CUENTA = ww_nrcuent;
         --actualizar el estado con el pag_cta para poder reversar
         pag_cta.pr_set_variables(v_cod_usuario,
                                  ww_fcvalor,
                                  ww_cdtranp,--cancelación
                                  'N',--estado mvto
                                  'N',--reversado
                                  v_secuencia,
                                  ww_esctaol, -- estado
                                  ww_cdofici,
                                  ww_cdmodul,
                                  ww_cdmodal);
         PAG_CTA.PR_ACT_ESTADO(ww_nrcuent,ww_esctaol,ww_fcvalor,v_hor_mov,null,'S');--procesar
         v_secuencia := nvl(v_secuencia, 0) + 1;
         IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
            raise_application_error(-20000,'Act.Est.'||pag_cta.fu_obt_msj_error());
         END IF;
     End If;


   End If;

Exception
  When OTHERS Then
     raise_application_error(-20000,'En pp_movimientos '||' ww_cdtrans '||sqlerrm);
END;




--Genera los movimientos DEPURACION
PROCEDURE LP_MOVIMIENTOS_MIG (v_nro_cuenta in ge_cuentas.nro_cuenta%type,
  p_capital IN ge_movimientos.monto%type,  --Capital
  p_interes IN ge_movimientos.monto%type,  --Interes a Pagar
  p_cap_acre IN ge_movimientos.monto%type,  --Capital acreedor
  p_cap_deu IN ge_movimientos.monto%type,  --Capital acreedor
  p_prev_sob IN ge_movimientos.monto%type,  --Previsiones sobregiro
  p_prev_con IN ge_movimientos.monto%type,  --Previsiones contingencia
  p_lin_sob IN ge_movimientos.monto%type,  --Linea de Sobregiro
  p_embargo in ge_movimientos.monto%type

  )IS
   ww_fcvalor date := v_fec_actual;
   ww_cdmodul ge_movimientos.cod_modulo%type;
   ww_cdmodal ge_movimientos.cod_modalidad%type;
   ww_cdofici ge_movimientos.cod_oficina%type;
   ww_nrcuent ge_movimientos.nro_cuenta%type;
   ww_cdtranp ge_movimientos.cod_tra_padre%type := 301;
   ww_cdtrans ge_movimientos.cod_transaccion%type;
   ww_imtrans ge_movimientos.monto%type;
   ww_nrdocum ge_movimientos.nro_documento%type := null;
   ww_cdcausa ge_movimientos.cod_causa%type := sc_cdcausa;
   ww_emaviso ge_movimientos.emi_aviso%type;
   ww_cdtasas ge_movimientos.cod_tasa%type;
   ww_imtasas ge_movimientos.val_tasa%type;
   ww_esctaol ge_movimientos.est_cuenta%type := null;
   ww_cnmovim ge_movimientos.concepto%type := 'Dep.Cta.Can.';
   ww_montocargo ge_movimientos.monto%type := 0;
   ww_rubro ge_movimientos.cod_rubro%type := 0;
   v_tot_sob  ge_movimientos.monto%type:= 0;
   v_sal_cuenta number(18,2);
   v_cod_rub_can varchar2(100);
   v_cod_moneda varchar2(100);
   v_cotizacion number(18,4);
   v_mto_equ_local number(18,2);

BEGIN
  v_secuencia :=nvl(v_secuencia,0)+1;

   ww_cdmodul := sc_cdmodul;
   ww_cdmodal := sc_cdmodal;
   ww_cdofici := sc_cdofici;
   ww_nrcuent := v_nro_cuenta;
  v_sal_cta:=0;
  v_cod_rub_can:=NULL;
  v_cod_moneda:=null;
  begin
    select a.cod_moneda
     into v_cod_moneda
       from ge_cuentas a
         where a.nro_cuenta= v_nro_cuenta;


  exception
     when others then
        v_cod_moneda:=null;
  end;


    v_cotizacion:=null;
    v_mto_equ_local:=null;

  if   sc_cdmodal=31 then
    begin
      select nvl(a.sal_total,0)
        into v_sal_cta
         from ah_cta_vistas a
          where a.nro_cuenta=ww_nrcuent;
     exception
       when others then
          v_sal_cta:=0;
     end;
   else
      begin
      select nvl(a.sal_total,0)
        into v_sal_cta
         from cc_cta_corrientes a
          where a.nro_cuenta=ww_nrcuent;
     exception
       when others then
          v_sal_cta:=0;
     end;
    end if;
    --Si hay capital y es ahorro
   if nvl(p_capital,0)>0 and sc_cdmodul=3 and sc_cdmodal=31 then
      v_lugar := 'Movimiento_Capital Debito';
      ww_cdtranp  := 61   ;
      ww_cdtrans := 61; -- Debito
      ww_imtrans := p_capital; -- + nvl(v_sal_ret,0); --Se verificara que se realizará con el saldo retenido
      ww_emaviso := 'N';
      ww_cnmovim := 'Dep.Deb.Capital';
      ww_cdtasas :=  case nvl(cdtasim,0) when 0 then null else nvl(cdtasim,0) end;
      ww_imtasas :=  case nvl(vltasim,0) when 0 then null else nvl(vltasim,0) end;
      ww_rubro   := null;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);
      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,null,null);

       --Restamos saldo de la cuenta
      if v_sal_ret =0 then
         Update ah_cta_vistas
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;
      else
        --Para saldo retenido
         Update ah_cta_vistas
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;

         Update ge_cuentas
              set SAL_contable = 0
               where NRO_CUENTA = v_nro_cuenta;
       end if;

      v_lugar := 'Movimiento_Capital Credito';
      ww_cdtranp  := 80  ; --62
      ww_cdtrans :=  80; -- Credito
      ww_imtrans := p_capital; -- + nvl(v_sal_ret,0); --Se verificara que se realizará con el saldo retenido
      ww_emaviso := 'N';
      ww_cnmovim := 'Dep.Cre.Capital';
      ww_cdtasas :=  case nvl(cdtasim,0) when 0 then null else nvl(cdtasim,0) end;
      ww_imtasas :=  case nvl(vltasim,0) when 0 then null else nvl(vltasim,0) end;
      ww_rubro   :=  null;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);

      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,v_cotizacion,v_mto_equ_local);

   elsif nvl(p_capital,0)=0 and sc_cdmodul=3 and sc_cdmodal=31 then
       --Restamos saldo de la cuenta
      if v_sal_ret =0 then
         Update ah_cta_vistas
               set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;
      else
        --Para saldo retenido
         Update ah_cta_vistas
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;

         Update ge_cuentas
              set SAL_contable = 0
               where NRO_CUENTA = v_nro_cuenta;

      end if;
   end if;

    --Si hay interes a pagar y es ahorro
   if (nvl(p_interes,0)) >0 and sc_cdmodul=3 and sc_cdmodal=31 then
      v_lugar := 'Movimiento_Interes_a_Pagar Debito';
      ww_cdtranp  := 63   ;
      ww_cdtrans := 63; -- Debito
      ww_imtrans := nvl(p_interes,0) ;
      ww_emaviso := 'N';
      ww_cnmovim := 'Dep.Deb.Int.Capital';
      ww_cdtasas := null; -- Ver tasa
      ww_imtasas := null; -- Ver importe de Tasa
      ww_rubro   := null;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);
      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,null,null);
      v_lugar := 'Movimiento_Interes_a_Pagar Credito';
      ww_cdtranp  := 80; --62
      ww_cdtrans :=  80; -- Credito
      ww_imtrans := nvl(p_interes,0) ;
      ww_emaviso := 'N';
      ww_cnmovim := 'Dep.Cre.Int.Capital';
      ww_cdtasas := null; -- Ver tasa
      ww_imtasas := null; -- Ver importe de Tasa
      ww_rubro   := null;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);
      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,v_cotizacion,v_mto_equ_local);
   end if;

     --Si hay cap acreedor y es ctacte
   if nvl(p_cap_acre,0)>0 and sc_cdmodul=4 and sc_cdmodal=41 then
      v_lugar := 'Movimiento_Capital_acreedor (D)';
      ww_cdtranp  := 69  ;
      ww_cdtrans := 69; -- Ver transaccion
      ww_imtrans := p_cap_acre; --+ nvl(v_sal_ret,0);--Se verificara que se realizará con el saldo retenido
      ww_cnmovim := 'Dep.Deb.Cap.Acr.';
      ww_emaviso := 'N';
      ww_cdtasas := null; -- Ver tasa
      ww_imtasas := null; -- Ver importe de Tasa
      ww_rubro   := NULL;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);
      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,null,null);
      --Restamos saldo de la cuenta
      if v_sal_ret =0 then
         Update cc_cta_corrientes
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;
      else
         Update cc_cta_corrientes
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;

         Update ge_cuentas
              set SAL_contable = 0
               where NRO_CUENTA = v_nro_cuenta;
      end if;

      v_lugar := 'Movimiento_Capital_acreedor (C)';
      ww_cdtranp  := 81 ;  --68
      ww_cdtrans :=  81; -- Ver transaccion
      ww_imtrans := p_cap_acre;-- + nvl(v_sal_ret,0); --Se verificara que se realizará con el saldo retenido
      ww_cnmovim := 'Dep.Cre.Cap.Acr.';
      ww_emaviso := 'N';
      ww_cdtasas := null; -- Ver tasa
      ww_imtasas := null; -- Ver importe de Tasa
      ww_rubro   := null;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);

      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,v_cotizacion,v_mto_equ_local);
 end if;

    --Si hay cap deudor y es ctacte
   if nvl(p_cap_deu,0)<0 and sc_cdmodul=4 and sc_cdmodal=41 then
      v_lugar := 'Movimiento_Capital_Deudor(D)';
      ww_cdtranp  := 81  ;--70
      ww_cdtrans := 81; -- Ver transaccion
      ww_imtrans := p_cap_deu; -- + nvl(v_sal_ret,0); --Se verificara que se realizará con el saldo retenido
      ww_emaviso := 'N';
      ww_cnmovim := 'Dep.Deb.Cap.Deu.';
      ww_cdtasas := null; -- Ver tasa
      ww_imtasas := null; -- Ver importe de Tasa
      ww_rubro   := null;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);

      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,v_cotizacion,v_mto_equ_local);

      if v_sal_ret =0 then
         Update cc_cta_corrientes
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;
      else
         Update cc_cta_corrientes
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;

         Update ge_cuentas
              set SAL_contable = 0
               where NRO_CUENTA = v_nro_cuenta;


      end if;


      v_lugar := 'Movimiento_Capital_Deudor(C)';
      ww_cdtranp  := 71  ;
      ww_cdtrans := 71   ; -- Ver transaccion
      ww_imtrans := p_cap_deu; -- - nvl(v_sal_ret,0);--Se verificara que se realizará con el saldo retenido
      ww_emaviso := 'N';
      ww_cnmovim := 'Dep.Cre.Cap.Deu.';
      ww_cdtasas := null; -- Ver tasa
      ww_imtasas := null; -- Ver importe de Tasa
      ww_rubro   := null;
      ww_cdcausa := null;
      ww_nrdocum := to_number(v_nro_cuenta);
      lp_genera_movimientos (ww_fcvalor, ww_cdmodul, ww_cdmodal, ww_cdofici,
                      ww_nrcuent, ww_cdtranp, ww_cdtrans, ww_imtrans,
                      ww_nrdocum, ww_cdcausa, ww_emaviso, ww_cdtasas,
                      ww_imtasas, ww_esctaol, ww_cnmovim,ww_rubro,null,null);
   end if;

   if (nvl(p_cap_acre,0)=0 and nvl(p_cap_deu,0)=0 )and sc_cdmodul=4 and sc_cdmodal=41 then
      if v_sal_ret =0 then
         Update cc_cta_corrientes
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
               where NRO_CUENTA = v_nro_cuenta;
      else
         Update cc_cta_corrientes
              set ESTADO='C',
               FEC_CAM_ESTADO= v_fec_actual,
               SAL_TOTAL = nvl(SAL_TOTAL, 0) - nvl(v_sal_cta,0),
               SAL_TOT_BATCH = nvl(SAL_TOT_BATCH, 0) - nvl(v_sal_cta,0)
                  where NRO_CUENTA = v_nro_cuenta;

         Update ge_cuentas
              set SAL_contable = 0
               where NRO_CUENTA = v_nro_cuenta;
      end if;
    end if;

Exception
  When OTHERS Then
     raise_application_error(-20000,'En LP_MOVIMIENTOS_MIG. '||' ww_cdtrans '||sqlerrm);
END;





 -- Procedimiento interno para registrar los errores
   PROCEDURE lp_ins_log_error(p_men_error ge_pro_aut_logs.men_error%type)
   IS
     v_proceso NUMBER(3) := 156;
     pragma autonomous_transaction;
   BEGIN
     insert into ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
        values (v_proceso, 'PRG_CAN_CTA_PEN_CANC', sysdate, sysdate, p_men_error);
     commit; -- este commit solo afecta a la transaccion autonoma
   END;




/*********  PROCESO PRINCIPAL   **********************/
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
      v_est_modulo  := pae_cnf.fu_obt_est_modulo(4);
      PAE_CNF.G_PROGRAMA := 'GPPROFIN';
      IF v_est_modulo = 2 THEN
         v_horario     := 'D'; -- N=Cerrado, D=Abierto
         v_nocturno := 'N'; -- N=Abierto,  S=Cerrado
      ELSE
         v_horario     := 'N'; -- N=Cerrado, D=Abierto
         v_nocturno := 'S'; -- N=Abierto,  S=Cerrado
      END IF;
      pag_cta.g_horario := v_horario;
  --v_lugar:='Cargar datos a Dep.rar';
  --lp_car_dat_Dep.;
  v_secuencia:=1;
    --Obtenemos el ultimo dia del mes
   v_lugar:='Obt.Ult.dia hàbil mes ';
   begin
       select a.ult_dia_mes
         into v_fec_fin_de_mes
             from ge_calendarios a
                where cod_modulo = 1;
   exception
      when others then
         v_fec_fin_de_mes:=null;
   end;
  v_nro_sec:=0;
 for j in cur_cta_con_sal loop
      v_hor_mov:= to_char(sysdate, 'HH24:MI:SS');
      v_hor_mov := fug_obt_hor_disponible(v_fec_actual,v_hor_mov,v_cod_usuario,'N');
      sc_tie_bloqueo:='N';
      v_can_prev_sob:=0;
      sc_carimp:=0;
      SC_CDMONED:=null;
      SC_CDMONED:= j.cod_moneda;
      v_nro_cuenta_can:=null;
      v_nro_cuenta_can:=j.nro_cuenta;
      sc_cdofici:= j.cod_oficina;
      sc_cdmodul:=j.cod_modulo;
      sc_cdmodal:=j.cod_modalidad;
      v_mto_embargo:=0;
      v_sal_total:=0;
      v_sal_ret:=0;
      v_sal_ret:= j.sal_retenido;
      V_MTO_CRE_PENDIENTES:=0;
      V_MTO_DEB_PENDIENTES:=0;
      V_MTO_CRE_A_CONFIRMAR:=0;
      v_sal_cap_cc:=0;

      V_MTO_CRE_PENDIENTES:=NVL(J.MTO_CRE_PENDIENTES,0);
      V_MTO_DEB_PENDIENTES:=NVL(J.MTO_DEB_PENDIENTES,0);
      V_MTO_CRE_A_CONFIRMAR:=NVL(J.MTO_CRE_A_CONFIRMAR,0);
      v_secuencia:=1;


        v_nro_sec:= nvl(v_nro_sec,0) +1;
        if v_nro_sec >=900 then
           v_secuencia:=1;
           v_nro_sec:=1;
            pag_cta.pr_set_variables(v_cod_usuario,
                                      v_fec_actual,
                                      406,--cancelación
                                      'N',--estado mvto
                                      'N',--reversado
                                      v_secuencia,
                                      'N', -- estado
                                      j.cod_oficina,
                                      j.cod_modulo,
                                      j.cod_modalidad);

         end if;
      v_lugar:='Gen.Mov: '|| j.nro_cuenta;
       sc_cdmodul := j.cod_modulo;
       sc_cdmodal := j.cod_modalidad;
       sc_cdofici := j.cod_oficina;
      LP_MOVIMIENTOS(j.nro_cuenta);


      v_lugar:='Cargar Datos Dep.: '|| j.nro_cuenta;
      --Cargar datos Dep.
          if j.cod_modulo = 3 then
             --dbms_output.put_line('Nro.Cta: '||v_nro_cuenta_can||' 14: ' ||to_char(sysdate,'hh24:mi:ss'));
              --AH
              v_capital:= 0;
              v_interes:= 0;
              if trunc(v_fec_fin_de_mes) = trunc(v_fec_actual) then
                 --Solo se pasa si se capitaliza trimestral
                 if j.tip_capitalizacion > 1 then
                   v_sal_dev_acu:= j.mto_devengado;
                 else
                   v_sal_dev_acu:= 0;
                 end if;
              else
                 v_sal_dev_acu:= j.mto_devengado;
                 v_interes:= v_sal_dev_acu; --> Asignaremos el ultimo devengado
              end if;

              --v_capital:= j.sal_contable;
              if j.sal_contable >= 0 then
                IF v_mto_embargo > 0 then
                  v_capital:= j.sal_capital;
                else
                  v_capital:= j.sal_contable;
                end if;
              end if;
              v_sal_total:= j.sal_total;

              --ctacte
              v_cap_acre:= 0;  --Capital acreedor
              v_cap_deu:= 0;  --Capital deudor
              v_prev_sob:=0;  --Previsiones sobregiro
              v_prev_con:=0; --Previsiones contingencia;
              v_lin_sob:=0; --Linea de Sobregiro
          elsif j.cod_modulo  = 4 then
               --dbms_output.put_line('Nro.Cta: '||v_nro_cuenta_can||' 15: ' ||to_char(sysdate,'hh24:mi:ss'));
              --ah
              v_capital:= 0;
              v_interes:= 0;
              --cc
              v_prev_sob:=0;  --Previsiones sobregiro
              v_prev_con:=0; --Previsiones contingencia;
              v_prev_sob:= j.mto_prev_sob;--Previsiones sobregiros
              v_prev_con:= j.mto_prev_con; --Previsiones contingencia;
              v_lin_sob:= 0;--v_lin_sob:= j.linea_sob; --Linea de Sobregiro No afecta contablemente en ola1

              v_cap_acre:= 0;  --Capital acreedor
              v_cap_deu:= 0;  --Capital deudor
              v_sal_cap_cc:=0;

               if j.sal_contable >= 0 then
                IF v_mto_embargo > 0 then
                  v_sal_cap_cc:= j.sal_capital;
                else
                  v_sal_cap_cc:= j.sal_contable;
                end if;
              ELSE
                v_sal_cap_cc:= j.sal_contable;
              end if;
              --
              if v_sal_cap_cc >= 0 then
                v_cap_acre:= v_sal_cap_cc;
              else
                v_cap_deu:= v_sal_cap_cc;
              end if;
            v_sal_total:= j.sal_total;
              --lp_obt_dat_saldo(v_nro_cuenta_can,v_cap_acre,v_cap_deu);

          end if;



      v_lugar:='Gen.Mov Dep.: '|| j.nro_cuenta;
      --dbms_output.put_line('Nro.Cta: '||v_nro_cuenta_can||' 18: ' ||to_char(sysdate,'hh24:mi:ss'));
      --Si generamos movimiento de DEPURACION, tambien inhibimos al cliente por DEPURACION
      if nvl(upper(v_gen_mov_MIG),'N')='S' THEN
            LP_MOVIMIENTOS_MIG( j.nro_cuenta,
              --ah
              v_capital,  --Capital
              v_interes,  --Interes a Pagar
              --cc
              v_cap_acre,  --Capital acreedor
              v_cap_deu,  --Capital deudor
              v_prev_sob,  --Previsiones sobregiro
              v_prev_con,  --Previsiones contingencia
              v_lin_sob,    --Linea de sobregiro
              v_mto_embargo  --Embargo
             );

      end if;

      update GE_DAT_CANCELACION h set h.procesado='S' where h.nro_cuenta=j.nro_cuenta;
      commit;
 end loop;





EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error en PRG_CAN_CTA_PEN_CANC, CTA: '||v_nro_cuenta_can||' '||v_lugar||' - ' || sqlerrm);
    --lp_ins_log_error(SUBSTR('Error en PRG_CAN_CTA_PEN_CANC, CTA: '||v_nro_cuenta_can||' '||v_lugar||' - ' || sqlerrm,1,500));
end PRG_CAN_CTA_PEN_CANC;
/

