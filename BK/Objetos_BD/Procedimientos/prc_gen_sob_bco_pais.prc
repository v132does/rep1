CREATE OR REPLACE PROCEDURE IT."PRC_GEN_SOB_BCO_PAIS"
 IS
RV_GCALE GE_CALENDARIOS%ROWTYPE;
V_FCDEHOY DATE;
R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
VIMPORTE GE_MOVIMIENTOS.VAL_TASA%TYPE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_FCANTER GE_CALENDARIOS.FEC_ANTERIOR%TYPE;

PROCEDURE lp_gen_sob_actual IS
  v_cdmodul NUMBER;
  v_cdmodal NUMBER;
  v_cdofici NUMBER;
  v_cdmoned VARCHAR2(3);
  v_sldeudo NUMBER;
  v_nrcuent VARCHAR2(15);
  v_cnmovim VARCHAR2(35);
----------------------------------------------------------
CURSOR cur3 IS
  select cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
         cod_moneda, abs(nvl(sal_total,0) - nvl(sal_retenido,0))
    from cc_cta_bancarias
   where estado <> 'C'
     --WA: 08/08/2014 se incluye modalidad 49
     and cod_modalidad in (42,45,48,442,49)
     and nvl(sal_total,0) - nvl(sal_retenido,0) > 0;
vAcuerdo      number(14,2);
vImporte      number(14,2);
vImtrans      number(14,2);
v_secuencia   number(4) := 0;
v_cod_rubro   cb_rubros.cod_rubro%type;
v_cod_rub_bco cb_rubros.cod_rubro%type;
BEGIN
    OPEN cur3;
    LOOP
      FETCH cur3 INTO v_cdmodul, v_cdmodal, v_cdofici, v_nrcuent,
                      v_cdmoned, v_sldeudo;
      EXIT WHEN cur3%NOTFOUND;
      Begin
           -- Sumo los acuerdos permanentes para ver si esta utilizando o no
           vAcuerdo := 0;
           vImporte := 0;
           vImtrans := v_sldeudo;
           if v_cdmodal = 49 then
              v_cnmovim := 'SOBREG.VIGENTE FIN.PAIS: '||TO_CHAR(1,'9999')||' DIAS';
           else
              v_cnmovim := 'SOBREG.VIGENTE BCO.PAIS: '||TO_CHAR(1,'9999')||' DIAS';
           end if;
           ---
           begin
             select a.cod_rubro
               into v_cod_rub_bco
               from cc_cta_bancarias a
              where a.nro_cuenta = v_nrcuent
                and a.cod_modulo = v_cdmodul
                and a.cod_modalidad = v_cdmodal;
           exception
               when no_data_found then
                    raise_application_error(-20000, 'ERROR. No se encontro Rubro Cta.Bancaria '
                                           ||v_nrcuent);
               when others then
                    raise_application_error(-20000, 'ERROR:Obt.Rub.Sob.'
                                           ||'Cta.Bancaria:'||sqlerrm);
           end;
           ---
           v_cod_rubro := fug_obt_paradicional(v_nrcuent,'COD_RUB_SOB_CTA_BAN');
           if v_cod_rubro is null then
              v_cod_rubro := v_cod_rub_bco;
           end if;

           if v_secuencia + 1 > 990 then
              v_secuencia := 0;
              --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
              --FQ Para evitar error de PK
              v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
           end if;
           --si tiene alguno de los importes
           If vImtrans > 0 Then
             v_secuencia := v_secuencia + 1;
             -- Acredito en el rubro del sobregiro
             r_gmovi.cod_modulo      := v_cdmodul;
             r_gmovi.cod_modalidad   := v_cdmodal;
             r_gmovi.cod_oficina     := v_cdofici;
             r_gmovi.nro_cuenta      := v_nrcuent;
             r_gmovi.cod_moneda      := v_cdmoned;
             r_gmovi.cod_usuario     := user;
             r_gmovi.hora            := v_hora;
             r_gmovi.fecha           := v_fcdehoy;
             --
             r_gmovi.fec_valor       := v_fcdehoy;
             r_gmovi.cod_mod_padre   := v_cdmodul;
             r_gmovi.cod_mad_padre   := v_cdmodal;
             r_gmovi.nro_documento   := null;
             r_gmovi.nro_documento2  := null;
             r_gmovi.nro_documento3  := null;
             r_gmovi.cod_tasa        := null;
             r_gmovi.val_tasa        := null;
             r_gmovi.cotizacion      := null;
             r_gmovi.cod_ofi_origen  := v_cdofici;
             r_gmovi.emi_aviso       := 'N';
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             r_gmovi.nro_secuencia   := v_secuencia;
             r_gmovi.cod_tra_padre   := 902;
             r_gmovi.cod_transaccion := null;
             r_gmovi.monto           := vImtrans;
             r_gmovi.concepto        := v_cnmovim;
             r_gmovi.cod_rubro       := v_cod_rubro;
             r_gmovi.tip_mov_rubro   := 'C';
             pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
             --
             -- Debito de la Cta.Bancaria
             --
             v_secuencia := v_secuencia + 1;
             r_gmovi.cod_modulo      := v_cdmodul;
             r_gmovi.cod_modalidad   := v_cdmodal;
             r_gmovi.cod_oficina     := v_cdofici;
             r_gmovi.nro_cuenta      := v_nrcuent;
             r_gmovi.cod_moneda      := v_cdmoned;
             r_gmovi.cod_usuario     := user;
             r_gmovi.hora            := v_hora;
             r_gmovi.fecha           := v_fcdehoy;
             --
             r_gmovi.fec_valor       := v_fcdehoy;
             r_gmovi.cod_mod_padre   := v_cdmodul;
             r_gmovi.cod_mad_padre   := v_cdmodal;
             r_gmovi.nro_documento   := null;
             r_gmovi.nro_documento2  := null;
             r_gmovi.nro_documento3  := null;
             r_gmovi.cod_tasa        := null;
             r_gmovi.val_tasa        := null;
             r_gmovi.cotizacion      := null;
             r_gmovi.cod_ofi_origen  := v_cdofici;
             r_gmovi.emi_aviso       := 'N';
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             r_gmovi.nro_secuencia   := v_secuencia;
             r_gmovi.cod_tra_padre   := 902;
             r_gmovi.cod_transaccion := null;
             r_gmovi.monto           := vImtrans;
             r_gmovi.concepto        := v_cnmovim;
             r_gmovi.cod_rubro       := v_cod_rub_bco;
             r_gmovi.tip_mov_rubro   := 'D';
             pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
           End If;
      End;
    END LOOP;   -- fin del ciclo de Principal
EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20000, 'ERROR. en Sobregiro '||SQLERRM);
END;
PROCEDURE lp_can_sob_anterior IS
cursor mov is
select distinct hora
  from cc_movimientos_his
 where fecha = v_fcanter
   and cod_modulo = 4
   --WA: 08/08/2014 se incluye modalidad 49
   and cod_modalidad in (42,45,48,442,49)
   and cod_tra_padre = 902 --Sobregiro Vigente--
   and monto > 0
   order by hora;
BEGIN
--- inserto en ge_movimientos mov. inversos a los sobreg. del dia ant.--
   for reg in mov loop
      insert into ge_movimientos
            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
             cod_tra_padre,cod_transaccion,fecha,fec_valor,
             monto,estado,concepto,reversado,
             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
             nro_secuencia,nro_cuenta,cod_ofi_origen,
             cod_rubro,tip_mov_rubro)
      select cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
             cod_tra_padre,cod_transaccion,v_fcdehoy,v_fcdehoy,
             monto * -1,estado,decode(cod_modalidad,49,'Cancelación Sobregiros Fin.Pais','Cancelación Sobregiros Bco.Pais'),reversado,
             cod_mod_padre,cod_mad_padre,user, v_hora,
             nro_secuencia,nro_cuenta,cod_ofi_origen,
             cod_rubro,tip_mov_rubro
        from CC_MOVIMIENTOS_HIS
       where fecha = v_fcanter
         and hora = reg.hora
         and cod_modulo = 4
         --WA: 08/08/2014 se incluye modalidad 49
         and cod_modalidad in (42,45,48,442,49)
         and cod_tra_padre = 902 --Sobregiro Vigente--
         and monto > 0
         order by nro_secuencia;
      --obtener sig segundo para el prox ciclo
      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --FQ Para evitar error de PK
      v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
   end loop;
--------------------------------------------------------------------
EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR. Sobregiro_Cancelacion '||SQLERRM);
END;
BEGIN
   v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
   rv_gcale  := pag_cal.fu_obt_reg_cal(4);
   v_FCANTER := rv_gcale.fec_anterior;
   --inicializa hora para los movimientos
   --v_hora    := fug_ini_hora(sysdate, 'HH24:MI:SS');
   --FQ Para evitar error de PK
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
   --genera los movimientos por los sobregiros generados
   lp_gen_sob_actual;
   --para q no caiga por pk
   --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
   --FQ Para evitar error de PK
   v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
   --cancela los mov del dia anterior levantando desde el histórico, y
   --generando estos movimientos en negativo
   lp_can_sob_anterior;
END PRC_GEN_SOB_BCO_PAIS;
/

