CREATE OR REPLACE PROCEDURE IT.prg_rev_inf_cobranza ( p_hor_referencia  IN ge_mov_dat_adicionales.hor_referencia%type,
                                                   p_cod_mod_padre   IN ge_movimientos.cod_mod_padre%TYPE,
                                                   p_cod_mad_padre   IN ge_movimientos.cod_mad_padre%TYPE,
                                                   p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                                                   p_nro_doc_infonet IN ge_movimientos.nro_documento3%TYPE,
                                                   p_nro_documento   IN ge_movimientos.nro_documento%TYPE,
                                                   p_monto           IN ge_movimientos.monto%TYPE,
                                                   p_mto_comision    IN ge_movimientos.monto%TYPE,
                                                   p_cod_moneda      IN ge_movimientos.cod_moneda%TYPE,
                                                   p_nro_cta_debito  IN ge_movimientos.nro_cuenta%TYPE,
                                                   p_cod_bco_debito  IN ge_movimientos.cod_banco%type,
                                                   p_nro_cta_credito IN ge_movimientos.nro_cuenta%type,
                                                   p_cod_bco_credito IN ge_movimientos.cod_banco%type,
                                                   p_cod_bco_atm     IN ge_ext_infonet_tmp.cod_bco_atm%type,
                                                   p_nro_atm         IN ge_ext_infonet_tmp.nro_atm%type,
                                                   p_negocio         IN varchar2,
                                                   p_dat_adicional   IN varchar2,
                                                   p_tip_operacion   IN varchar2,
                                                   p_actualiza       IN OUT varchar2,
                                                   p_det_error       OUT varchar2) IS
     PRAGMA AUTONOMOUS_TRANSACTION;
     v_nro_cta_credito ge_movimientos.nro_cuenta%type;
     v_nro_cta_debito ge_movimientos.nro_cuenta%type;
     v_tip_cuenta varchar2(2);
     v_actualiza     VARCHAR2(1);
     v_monto ge_movimientos.monto%type;
     v_mto_comision ge_movimientos.monto%type;
     v_ofi_origen ge_movimientos.cod_oficina%type;
     v_cod_rub_caja ge_movimientos.cod_rubro%type;
     v_nro_caja        cj_movimientos.nro_caja%type;
     v_cod_bco_credito ge_movimientos.cod_banco%type;
     v_cod_ent_financiera cc_cta_corrientes.cod_ente%type;
     v_sal_disponible ah_cta_vistas.sal_total%type;
     v_mto_acuerdo    cc_lin_sobregiros.monto%type;
     v_cod_persona    ba_personas.cod_persona%type;
     v_ind_rub_debito   varchar2(1) := 'N';
     v_tra_con_debito   ge_movimientos.cod_transaccion%type;
     v_mod_con_debito   ge_movimientos.cod_modulo%type;
     v_mad_con_debito   ge_movimientos.cod_modalidad%type;
     v_cod_rub_debito   ge_movimientos.cod_rubro%type;
     v_nro_cta_fic_cre  cc_cta_ficticias.nro_cuenta%type;
     v_ind_rub_credito  varchar2(1) := 'N';
     v_tra_con_credito  ge_movimientos.cod_transaccion%type;
     v_mod_con_credito  ge_movimientos.cod_modulo%type;
     v_mad_con_credito  ge_movimientos.cod_modalidad%type;
     v_ofi_con_credito  ge_movimientos.cod_oficina%type;
     v_cod_rub_credito  ge_movimientos.cod_rubro%type;
     v_cod_moneda ge_movimientos.cod_moneda%type := p_cod_moneda;
     v_acu_sobregiro varchar2(1);
     v_cta_combinada varchar2(1);
     v_cod_ent_sueldo ge_entes.cod_ente%type;
     v_mod_cta_cre ge_movimientos.cod_modulo%type;
     v_mad_cta_cre ge_movimientos.cod_modalidad%type;
     v_mon_cta_cre ge_movimientos.cod_moneda%type;
     v_ofi_cta_cre ge_movimientos.cod_oficina%type;
     v_mod_cta_deb ge_movimientos.cod_modulo%type;
     v_mad_cta_deb ge_movimientos.cod_modalidad%type;
     v_mon_cta_deb ge_movimientos.cod_moneda%type;
     v_ofi_cta_deb ge_movimientos.cod_oficina%type;
     v_imp_debito  ge_movimientos.monto%type;
     v_imp_credito  ge_movimientos.monto%type;
     v_fec_actual  ge_movimientos.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(3);
     v_cot_debito      ge_movimientos.cotizacion%type;
     v_cot_credito     ge_movimientos.cotizacion%type;
     g_cod_error pag_cta.G_COD_ERROR%type;
     v_est_cta_cre ge_cuentas.estado%type;
     v_nro_cta_cliente varchar2(20);
     v_nro_cta_tarjeta varchar2(20);
     R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
     v_hora ge_movimientos.hora%type := to_char(SYSDATE,'hh24:mi:ss');
     v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
     v_msj_error VARCHAR2(2000);
     v_nro_cta_combinada varchar2(30) := '';
     v_sal_dis_debito    number(18,2) := 0;
     v_est_cuenta  ge_cuentas.estado%type;
     v_est_cta_comb ge_cuentas.estado%type;
     v_cod_usuario ba_usuarios.cod_usuario%type := user;
     v_fec_valor date:=trunc(sysdate);
     --comisión bancard de infonet cobranzas
     v_cod_mod_com_ban ba_modulos.cod_modulo%type;
     v_cod_mad_com_ban ge_modalidades.cod_modalidad%type;
     v_cta_com_bancard ge_cuentas.nro_cuenta%type;
     v_cod_rub_facturador cb_rubros.cod_rubro%type;
     v_cod_ofi_comision ba_oficinas.cod_oficina%type;
     v_ind_obt_comision varchar2(1) := 'N';
     v_ind_acr_batch    varchar2(1) := 'N';

     v_est_cta_com_ban cc_cta_corrientes.estado%type;
     vp_nro_tarjeta varchar2(16);
     v_nro_tarjeta varchar2(25);
     v_negocio varchar2(40);

     procedure lp_dat_cta (p_nro_cuenta in out varchar2,
                           p_cod_modulo out number,
                           p_cod_modalidad out number,
                           p_cod_oficina   out number,
                           p_cod_moneda out varchar2) is
        v_cod_ent_ahorro number(5);
      begin
        If p_nro_cuenta is null then
          -- Es una cuenta contable...
          p_cod_modulo    := v_mod_con_debito;
          p_cod_modalidad := v_mad_con_debito;
          p_cod_oficina   := v_ofi_origen;
          p_cod_moneda    := v_cod_moneda;
          v_acu_sobregiro := 'N';
          v_cta_combinada := 'N';
        Else
          v_cta_combinada := 'N';
          Select cod_modulo, cod_modalidad, cod_oficina
            into p_cod_modulo, p_cod_modalidad, p_cod_oficina
            from ge_cuentas
           where nro_cuenta = p_nro_cuenta;
          If p_cod_modalidad = 31 then
            select nvl(cta_combinada,'N'), cod_moneda, 'N', cod_ente
              into v_cta_combinada, p_cod_moneda, v_acu_sobregiro, v_cod_ent_ahorro
              from ah_cta_vistas
             where nro_cuenta = p_nro_cuenta;
          elsif p_cod_modalidad = 41 then
            select cod_moneda, acu_sobregiro, cod_ente, nvl(cta_combinada,'N')
              into p_cod_moneda, v_acu_sobregiro, v_cod_ent_sueldo, v_cta_combinada
              from cc_cta_corrientes
             where nro_cuenta = p_nro_cuenta;
          --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
          elsif p_cod_modalidad = 49 then
            select cod_moneda, 'N', cod_ente, 'N'
              into p_cod_moneda, v_acu_sobregiro, v_cod_ent_sueldo, v_cta_combinada
              from cc_cta_bancarias
             where nro_cuenta = p_nro_cuenta;
          End if;
        End if;
     Exception
        When NO_DATA_FOUND Then
          v_actualiza := 'N';
          p_det_error := 'No se encuentra los datos de la cuenta';
     end lp_dat_cta;

     procedure lp_ins_log_extornos is
       PRAGMA AUTONOMOUS_TRANSACTION;
     Begin
       begin
         insert into LOG_ATM_EXTORNOS(NRO_TRANSACCION) values(p_nro_doc_infonet);
         commit;
       exception
         -- si salta error PK es por que ya existe extorno pero fallaron controles iniciales
         -- en se impide que continue el extorno
         when DUP_VAL_ON_INDEX then
           v_actualiza := 'N';
           p_det_error := 'Extorno Duplicado';
         when others then
           v_actualiza := 'N';
           p_det_error := 'Error al querer ingresar el log del Extorno';
       end;
     End lp_ins_log_extornos;

     procedure lp_con_mon_a_moneda(p_cod_mon_debito  in ba_monedas.cod_moneda%type,
                                  p_cod_mon_credito in ba_monedas.cod_moneda%type,
                                  p_mto_mon_debito  in out number,
                                  p_mto_mon_credito in out number,
                                  p_cot_mon_debito  out number,
                                  p_cot_mon_credito out number) is
        v_lugar         varchar2(100);
        v_cod_mon_local varchar2(3) := pag_gen.fu_obt_mon_local;
	   begin
        v_lugar := 'obtener moneda base';
        if p_cod_mon_debito = p_cod_mon_credito then
           if p_mto_mon_debito is null then
              p_mto_mon_debito  := p_mto_mon_credito;
           else
              p_mto_mon_credito := p_mto_mon_debito;
           end if;
           p_cot_mon_credito := null;
           p_cot_mon_debito  := null;
        else
          if p_cod_mon_debito = v_cod_mon_local then -- VENTA
            p_cot_mon_debito  := null;
            p_cot_mon_credito := paw_bce.fu_obt_cotizacion(p_cod_mon_credito, 'V');
            if p_mto_mon_debito is null then
              p_mto_mon_debito  := round(p_mto_mon_credito * p_cot_mon_credito, 0);
            else
              p_mto_mon_credito := round(p_mto_mon_debito / p_cot_mon_credito, 2);
              p_cot_mon_credito := round(p_mto_mon_debito / p_mto_mon_credito, 4);  -- relacula la cotizacion
            end if;
          elsif p_cod_mon_credito = v_cod_mon_local then -- COMPRA
            p_cot_mon_debito  :=  paw_bce.fu_obt_cotizacion(p_cod_mon_debito, 'C'); --DYDMR-4929 Se pasa como parametro la moneda de debito para las compras
            p_cot_mon_credito := null;
            if p_mto_mon_debito is null then
              p_mto_mon_debito  := round(p_mto_mon_credito / p_cot_mon_debito, 2);
              p_cot_mon_debito  := round(p_mto_mon_credito / p_mto_mon_debito, 4); -- relacula la cotizacion
            else
              p_mto_mon_credito := round(p_mto_mon_debito * p_cot_mon_debito, 0);
            end if;
         end if;
        end if;
  exception
    when others then
      raise_application_error(-20000, v_lugar || ' - ' || sqlerrm);
  end;

   function lf_exi_banco (p_cod_banco number) return varchar2 is
     v_exi_banco varchar2(1) := 'N';
   begin
     --WA: 06/08/2014 Buscamos inicialmente si es financiera
     begin
       select 'S'
        into v_exi_banco
         from ge_par_entes p, ge_entes e
        where p.parametro = 'COD_ENT_FINANCIERA'
          and p.cod_ente = e.cod_ente
          and p.val_parametro=p_cod_banco
          and e.tipo = 'FI';
     exception
        when no_data_found then
          v_exi_banco:='N';
        when others then
          v_exi_banco:='N';
     end;

     if nvl(v_exi_banco,'N')= 'N' then
       begin
        Select 'S'
           into v_exi_banco
           from ge_bancos
          where cod_banco = p_cod_banco
               and estado = 'A'
               and ubicacion = 'L';
        Exception
          When NO_DATA_FOUND then
             return v_exi_banco;
        end;
     end if;
     return v_exi_banco;
   end lf_exi_banco;


   function lf_exi_financiera (p_cod_ente number) return varchar2 is
     v_exi_financiera varchar2(1) := 'N';
   begin
     --WA: 06/08/2014 Buscamos si es financiera
     begin
       select 'S'
        into v_exi_financiera
         from ge_par_entes p, ge_entes e
        where p.parametro = 'COD_ENT_FINANCIERA'
          and p.cod_ente = e.cod_ente
          and p.val_parametro=p_cod_ente
          and e.tipo = 'FI';
     exception
        when no_data_found then
          v_exi_financiera:='N';
        when others then
          v_exi_financiera:='N';
     end;
     return v_exi_financiera;
   end lf_exi_financiera;

   procedure lp_ins_ge_movimiento
   is
      v_ins_movimiento varchar2(1) := 'N';
      v_can_intentos   number := 0;
      v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
      v_liberado varchar2(1);
      v_fec_acreditacion date;
      v_tip_operacion ge_mov_dat_adicionales.tip_operacion%type;
      v_nro_cta_deb_batch ge_mov_dat_adicionales.nro_cta_deb_batch%type;
   begin
      if v_nro_secuencia > 996 then
         v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, v_cod_usuario, 'N');
         r_gmovi.hora    := v_hora;
         v_nro_secuencia := -999;
      end if;
      while v_ins_movimiento = 'N' and v_can_intentos <= 10 loop
         begin
            v_msj_error      := null; -- CORECTRB-2 ABR/2018
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N');
            v_ins_movimiento := 'S';
         exception
            when others then
               v_hora           := FUG_OBT_HOR_DISPONIBLE(v_fec_actual,
                                                          v_hora,
                                                          v_cod_usuario,
                                                          'N');
               r_gmovi.hora     := v_hora;
               v_ins_movimiento := 'N';
               v_can_intentos   := v_can_intentos + 1;
               v_msj_error      := sqlerrm;
         end;
      end loop;
      if v_ins_movimiento = 'N' then
         v_actualiza := 'N';
         raise_application_error(-20000, v_msj_error);
      else
         if r_gmovi.cod_modalidad in (41, 31) and r_gmovi.cod_tra_padre not in (425, 309) then
            begin
              select cod_sub_modalidad
                into v_cod_sub_modalidad
                from ge_cuentas
               where nro_cuenta = R_GMOVI.Nro_Cuenta;
            exception
              when others then
                v_cod_sub_modalidad := 1;
            end;
            if nvl(v_ind_acr_batch, 'N') = 'S' or v_cod_sub_modalidad = 25 then
               if v_ind_acr_batch = 'S' then
                  v_liberado := 'N';
                  v_tip_operacion := 'BCH';
                  v_nro_cta_deb_batch := v_nro_cta_debito;
               else
                  v_liberado := 'S';
                  v_tip_operacion := 'TRA';
                  v_fec_acreditacion := r_gmovi.fecha;
                  v_nro_cta_deb_batch := null;
               end if;
               declare
                  v_det_error ge_mov_dat_adicionales_err.det_error%type;
                  v_fec_cobro ge_mov_dat_adicionales.fecha%type;
                  v_hor_referencia ge_mov_dat_adicionales.hor_referencia%type;
               begin
                  begin
                     v_fec_cobro :=  trunc(sysdate);
                     v_hor_referencia := to_char(sysdate,'HH24:MI:SS');
                    insert into ge_mov_dat_adicionales (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                cod_modulo, cod_modalidad, nro_cuenta, nro_cta_deb_batch, cod_tra_padre,
                                                cod_moneda, monto, cod_extorno, nro_documento,
                                                nro_transaccion, liberado, fec_acreditacion, tip_operacion)
                                         values(r_gmovi.fecha, v_fec_cobro, r_gmovi.cod_usuario, R_GMOVI.hora, nvl(v_nro_secuencia, 1), v_hor_referencia,
                                                r_gmovi.cod_modulo, r_gmovi.cod_modalidad, r_gmovi.nro_cuenta, v_nro_cta_deb_batch, r_gmovi.cod_tra_padre,
                                                r_gmovi.cod_moneda, r_gmovi.monto, '99', r_gmovi.nro_documento,
                                                r_gmovi.nro_documento3, v_liberado, v_fec_acreditacion, v_tip_operacion);
                  exception
                    when others then
                      v_det_error := substr(sqlerrm, 1,4000);
                      v_fec_cobro :=  trunc(sysdate);
                      v_hor_referencia := to_char(sysdate,'HH24:MI:SS');
                      insert into ge_mov_dat_adicionales_err (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                      cod_modulo, cod_modalidad, nro_cuenta, nro_cta_deb_batch, cod_tra_padre,
                                                      cod_moneda, monto, cod_extorno, nro_documento,
                                                      nro_transaccion, liberado, fec_acreditacion, det_error, tip_operacion)
                                               values(r_gmovi.fecha, v_fec_cobro, r_gmovi.cod_usuario, R_GMOVI.hora, nvl(v_nro_secuencia, 1), v_hor_referencia,
                                                      r_gmovi.cod_modulo, r_gmovi.cod_modalidad, r_gmovi.nro_cuenta,v_nro_cta_deb_batch, r_gmovi.cod_tra_padre,
                                                      r_gmovi.cod_moneda, r_gmovi.monto, '99', r_gmovi.nro_documento,
                                                      r_gmovi.nro_documento3, v_liberado, v_fec_acreditacion, v_det_error, v_tip_operacion);
                  end;
                end;
              end if;
          end if;
      end if;
   end;

   function lf_nro_tarjeta(p_nro_tarjeta varchar2) return varchar2 is
     v_ret varchar2(25);
   begin
      v_ret := lpad('*',(length(p_nro_tarjeta)-6),'*')||substr(p_nro_tarjeta,-4);
      return v_ret;
   exception
     when others then
       return null;
   end;

   procedure lp_upd_cta_debito(p_mod_cta_deb in number, p_mad_cta_deb in number,
                               p_cta_debito in varchar2, p_imp_debito in number) is
   begin
     If v_ind_rub_debito = 'N' then
        -- Horario normal --
        if p_mad_cta_deb not in (42,46,49) then
        -------------------------------------------------------------------------------------------
        --Mejoras ATM DE-2209--Punto 1: Realizar 3 intentos para bloqueo de la Cuenta de Débito
        --cuando es de modalidad 41-Cuenta C orriente o 31-Caja de Ahorro.
        -------------------------------------------------------------------------------------------
            for v_can_int_bloqueo in 1..20 loop
                IF PAG_CTA.FU_LLAVEAR_CUENTA(p_mad_cta_deb, p_cta_debito, 'N') = 'N' Then
                   if v_can_int_bloqueo = 20 then
                      v_actualiza := 'N';
                      p_det_error := 'Cuenta Debito llaveada';
                      exit;
                   end if;
                else
                   exit;
                end if;
            end loop;
       End if;

       IF nvl(v_actualiza, 'N') = 'S' THEN
        If p_mad_cta_deb = 31 then
           update ah_cta_vistas
              set sal_total = nvl(sal_total,0) - p_imp_debito,
                  fec_ult_movimiento = v_fec_actual,
                  hor_ult_movimiento = v_hora,
                  estado = decode(estado, 'I', 'N', estado)
            where nro_cuenta = p_cta_debito;
        elsif p_mad_cta_deb = 41 then
          update cc_cta_corrientes
             set sal_total = nvl(sal_total,0) - p_imp_debito,
                 fec_ult_movimiento = v_fec_actual,
                 hor_ult_movimiento = v_hora,
                 estado = decode(estado, 'I', 'N', estado)
           where nro_cuenta = p_cta_debito;
        End if;
       END IF;
     end if;
   end lp_upd_cta_debito;

   procedure lp_upd_cta_credito is
   begin
     If v_ind_rub_credito = 'N' then
        --Mejoras ATM DE-2209--Punto 3: No Bloquear la Cuenta de Crédito cuando sea Cuenta Bancaria
        if v_mad_cta_cre not in (42,46,49) then
            ------------------------------------------------------------------------------------------
            --Mejoras ATM DE-2209--Punto 2: Realizar 3 intentos para bloqueo de la Cuenta de Credito
            --cuando es de modalidad 41-Cuenta Corriente o 31-Caja de Ahorro.
            --Solo posterior a ello generar el error 19-Reintente
            ------------------------------------------------------------------------------------------
            for v_can_int_bloqueo in 1..20 loop
                IF PAG_CTA.FU_LLAVEAR_CUENTA(v_mad_cta_cre, v_nro_cta_credito, 'N') = 'N' Then
                   if v_can_int_bloqueo = 20 then
                      v_actualiza := 'N';
                      p_det_error := 'Cuenta Crédito llaveada';
                      exit;
                   end if;
                else
                   exit;
                end if;
            end loop;
          end if;

         -- Horario normal --
         IF nvl(v_actualiza, 'N') = 'S' THEN
           If v_mad_cta_cre = 31 then
             update ah_cta_vistas
                set sal_total = nvl(sal_total, 0) + v_imp_credito,
                    estado = decode(estado, 'I', 'N', estado)
              where nro_cuenta = v_nro_cta_credito;
           elsif v_mad_cta_cre = 41 then
             update cc_cta_corrientes
                set sal_total = nvl(sal_total, 0) + v_imp_credito,
                    estado = decode(estado, 'I', 'N', estado)
              where nro_cuenta = v_nro_cta_credito;
           End if;
        END IF;
     end if;
   end lp_upd_cta_credito;


   procedure lp_upd_cta_ban(p_mad_cta_ban number, p_nro_cta_ban varchar2,
                            p_monto number) is
     v_exi_cta_ban varchar2(1);
   begin
     If v_ind_rub_credito = 'N' then
        for v_can_int_bloqueo in 1..20 loop
          IF PAG_CTA.FU_LLAVEAR_CUENTA(p_mad_cta_ban, p_nro_cta_ban, 'N') = 'N' Then
             if v_can_int_bloqueo = 20 then
                v_actualiza := 'N';
                p_det_error := 'Cuenta Bancaria llaveada';
                exit;
                end if;
              else
                 exit;
              end if;
          end loop;

          -- Horario normal --
          IF nvl(v_actualiza, 'N') = 'S' THEN
             update cc_cta_bancarias a
                set sal_total = nvl(sal_total, 0) + p_monto,
                    estado = decode(estado, 'I', 'N', estado),
                    fec_ult_movimiento = v_fec_actual,
                    hor_ult_movimiento = v_hora
              where nro_cuenta = p_nro_cta_ban;
          END IF;
      end if;
   end lp_upd_cta_ban;


   BEGIN
     BEGIN
       v_actualiza := p_actualiza;
       v_nro_cta_credito := p_nro_cta_credito;
       v_nro_cta_debito := p_nro_cta_debito;
       v_ofi_origen := 7;

       if v_nro_cta_credito is not null and to_number(p_cod_bco_credito) = 7  then
           begin
             select val_maximo
               into v_nro_cta_credito
               from ba_cod_referencias r
              where dominio = 'COD_CTA_EQU_BBVA'
                and r.val_minimo = to_number(v_nro_cta_credito);
           exception
             when others then
                v_nro_cta_credito := p_nro_cta_credito;
           end;

           v_nro_cta_credito := substr('0000000000'||trim(v_nro_cta_credito),-10);
           v_tip_cuenta := substr(v_nro_cta_credito,4,1);
           if v_tip_cuenta in ('1','3') then
              v_tip_cuenta := '01';
              v_nro_cta_credito := substr(v_nro_cta_credito,2,2)||v_tip_cuenta||substr(v_nro_cta_credito, -6);
           elsif v_tip_cuenta in ('2','4') then
              v_tip_cuenta := '02';
              v_nro_cta_credito := substr(v_nro_cta_credito,2,2)||v_tip_cuenta||substr(v_nro_cta_credito, -6);
           end if;
       end if;
       if v_nro_cta_debito is not null and to_number(p_cod_bco_debito) = 7  then
          v_nro_cta_debito := substr('0000000000'||trim(v_nro_cta_debito),-10);
          v_tip_cuenta := substr(v_nro_cta_debito,4,1);
          if v_tip_cuenta in ('1','3') then
             v_tip_cuenta := '01';
             v_nro_cta_debito := substr(v_nro_cta_debito,2,2)||v_tip_cuenta||substr(v_nro_cta_debito, -6);
          elsif v_tip_cuenta in ('2','4') then
             v_tip_cuenta := '02';
             v_nro_cta_debito := substr(v_nro_cta_debito,2,2)||v_tip_cuenta||substr(v_nro_cta_debito, -6);
          end if;
       end if;


       if to_number(p_cod_bco_atm) = 7 Then
          -- Si es banco debe verificar la cuenta corriente
          Begin
            Select cod_oficina, nro_cuenta, cod_rubro, nro_caja
              into v_ofi_origen, v_nro_cta_credito, v_cod_rub_caja, v_nro_caja
              from cc_cta_cajeros
             where nro_caj_externo = v_nro_caja
               and cod_moneda = p_cod_moneda;

            v_cod_bco_credito := p_cod_bco_atm;
          Exception
             When NO_DATA_FOUND then
                if p_nro_cta_credito = '0' and to_number(p_cod_bco_credito) = 7 then
                   v_actualiza := 'N';
                   p_det_error := 'No se encuentra el número de Cuenta';
                end if;
          End;
       else
         v_cod_bco_credito := p_cod_bco_credito;
       End if;

       -- Si la Cuenta de credito no es del Banco.
       If to_number(v_cod_bco_credito) not in (7, 0) then
          Begin
             /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
               En la Procesadora Parametrizado.*/
             Select cod_ente
               into v_cod_ent_financiera
               from ge_par_entes a
              where a.parametro = 'COD_ENT_FINANCIERA'
                and to_number(a.val_parametro) = to_number(v_cod_bco_credito); --wa:30/07/2014 to_number(vp_bco_atm);
          Exception
             When NO_DATA_FOUND then
                v_cod_ent_financiera := NULL;
          End;

          Begin
            Select nro_cuenta
              into v_nro_cta_credito
              from cc_cta_bancarias
             where ((cod_banco     = to_number(v_cod_bco_credito) --wa:30/07/2014 to_number(vp_bco_atm);
               and cod_modalidad = 42) -- Modalidad de ATM'S Bancos.
                 or (cod_ente = to_number(v_cod_ent_financiera)
               and cod_modalidad = 49)) -- Modalidad de ATM'S Financieras.wa:31/07/2014 parentesis por logica
               and cod_moneda    = p_cod_moneda;
            Exception
              When NO_DATA_FOUND then
                v_actualiza := 'N';
                p_det_error := 'No se encuentra el número de Cuenta Bancaria.';
            End;
          End if;
          -- Si la Cuenta de debito no es del Banco.
          If to_number(P_cod_bco_debito) not in (7) then
            Begin
               /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
                 En la Procesadora Parametrizado.*/
               Select cod_ente
                 into v_cod_ent_financiera
                 from ge_par_entes a
                where a.parametro = 'COD_ENT_FINANCIERA'
                  and to_number(a.val_parametro) =to_number(p_cod_bco_debito); --wa:30/07/2014 to_number(vp_bco_atm);
            Exception
                When NO_DATA_FOUND then
                   v_cod_ent_financiera := NULL;
            End;

            Begin
             Select NRO_CUENTA
               into v_nro_cta_debito
               from cc_cta_bancarias
              where ((cod_banco     = to_number(p_cod_bco_debito) --wa:30/07/2014 to_number(vp_bco_atm);
                 and cod_modalidad = 42) -- Modalidad de ATM'S Bancos.
                  or (cod_ente = to_number(v_cod_ent_financiera)
                 and cod_modalidad = 49)) -- Modalidad de ATM'S Financieras.wa:31/07/2014 parentesis por logica
                 and cod_moneda    = p_cod_moneda;
            Exception
              When NO_DATA_FOUND then
                v_actualiza := 'N';
                p_det_error := 'No se encuentra el número de Cuenta Bancaria - Debito';
            End;
       End if;

       v_monto := p_monto * -1;
       v_mto_comision := p_mto_comision * -1;

       -- tys: realiza la conversion de montos
       if nvl(v_actualiza, 'S') = 'S'  then
         if v_cod_moneda <> v_mon_cta_deb then -- si la moneda de la operacion es distinta a la moneda de la cuenta de debito
           -- realiza la conversión de monto credito -> debito. el importe de debito de estar nulo
           v_imp_debito  := null;
           v_imp_credito := v_monto;
           lp_con_mon_a_moneda(v_mon_cta_deb, v_cod_moneda, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
         end if;
         if v_imp_debito is null then
           v_imp_debito := v_monto;
         end if;
         if v_mon_cta_cre <> v_mon_cta_deb then
           -- realiza la conversion de monto debito -> credito
           lp_con_mon_a_moneda(v_mon_cta_deb, v_cod_moneda, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
         end if;
         if v_imp_credito is null then
           v_imp_credito := v_monto;
         end if;
       end if;

       -- Hace las verificaciones si es clte de debito es nuestro....
       if  nvl(to_number(v_nro_cta_debito),0) != 0 then
          -- Obtiene los datos principales de la cuenta
          lp_dat_cta(v_nro_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);

         -- Verifica si el Cliente está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
          v_cod_persona := fug_obt_cli_principal(v_nro_cta_debito);
          if fug_obt_inhibicion(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'),v_cod_persona,v_nro_cta_debito) Then
             v_actualiza := 'N';
             p_det_error := 'Persona inhibida';
          end If;

          if nvl(v_actualiza, 'S') <> 'N' then
             --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
             if v_mad_cta_deb not in (31,41,42,48,46,49) and v_ind_rub_debito = 'N' Then -- Ahorro a la Vista/ Cta. Corrientes
                v_actualiza := 'N';
                p_det_error := 'No posee cuenta de débito ni rubro contable.';
             end if;
          End if;
          -- Debe verificar el monto de la operacion
          v_sal_disponible := nvl(pag_cta.FU_SAL_DISPONIBLE,0) - nvl(v_imp_debito,0);

          --Si la Cuenta no tiene Disponible se verifica el Disponible de la Cuenta Combinada
          if v_sal_disponible < 0 and nvl(v_actualiza, 'S') = 'S' then
             v_sal_disponible := nvl(pag_cta.g_ctas.SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
          end if;
          --Si aun no tiene disponible se verifica el Disponible de las dos cuentas (CTACTE + AV = FU_SAL_DIS_COMBINADA)
          if v_sal_disponible < 0 and nvl(v_actualiza, 'S') = 'S' then
             v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
          end if;
          --v_sal_disponible := nvl(pag_cta.FU_SAL_DIS_COMBINADA,0) - nvl(v_imp_debito,0);
          if v_sal_disponible < 0 and nvl(v_actualiza, 'S') = 'S' and
             --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
             v_mad_cta_deb not in (42,48, 46,49)  and v_ind_rub_debito = 'N' then
             If v_mad_cta_deb = 41 then
                -- Si es Cuenta Corriente debe verificar si no tiene acuerdo de Sobregiro.
                --If  v_acu_sobregiro = 'S' then
                   -- Debe buscar el monto del acuerdo para verificar nuevamente
                   v_mto_acuerdo := PAG_CTA.FU_OBT_LIN_SOBREGIRO(v_nro_cta_debito,v_fec_actual);
                   -- Para cuentas de plan sueldo no dar linea de sobregiro en el dia de cobro de sueldo TYS 14-03-08

                   If nvl(v_mto_acuerdo,0) + nvl(v_sal_disponible,0) < 0 then
                      -- Sigue siendo insuficiente su acuerdo...
                      v_actualiza := 'N'; -- No tiene saldo
                      p_det_error := 'Saldo insuficiente.';
                   Else
                      if to_number(p_tip_operacion) = 72 then -- infonet cobranzas
                         declare
                            v_tot_inf_cobranza number(18,2);
                         begin
                           select sum(monto)
                             into v_tot_inf_cobranza
                             from ge_mov_inf_cobranzas
                            where nro_cta_debito = v_nro_cta_debito
                              and liberado = 'N'
                              and reversado = 'N';
                           if nvl(v_mto_acuerdo,0) + nvl(v_sal_disponible,0) - nvl(v_tot_inf_cobranza,0) < 0 then
                              v_actualiza := 'N';
                              p_det_error := 'Saldo Insuficiente.';
                           else
                              v_actualiza := 'S';
                           end if;
                         end;
                      else
                        -- Sino mantiene aprobado.
                        v_actualiza := 'S';
                      end if;
                   End if;
                --Else
                   -- Si no es Cta Corriente debe responder Saldo Insuficiente...
                 --  vp_cod_respuesta := vr_sal_insuficiente; -- No tiene saldo
                --End if;
             Else
               -- Si no es Cta Corriente debe responder Saldo Insuficiente...
               v_actualiza := 'N'; -- No tiene saldo
               p_det_error := 'Saldo Insuficiente.';
             End if;
          end if;
          -- Carga la respuesta --
          --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
          If v_mad_cta_deb in (42, 48, 46,49) or v_ind_rub_debito = 'S' then
             v_sal_disponible := 0;
          End if;
      End if;
      -- Verifica si la cuenta es una cuenta ficticia...
      --
     v_ind_rub_debito  := 'N';
     v_tra_con_debito := null;
     v_mod_con_debito     := null;
     v_mad_con_debito     := null;
     v_cod_rub_debito        := null;

     v_ind_rub_credito  := 'N';
     v_tra_con_credito := null;
     v_mod_con_credito     := null;
     v_mad_con_credito     := null;
     v_cod_rub_credito        := null;
     v_nro_cta_cliente   := null;
     --
     if to_number(p_cod_bco_debito) = 7 then
         Begin
           select 'S', cod_transaccion, cod_modulo, cod_modalidad, cod_rubro, nro_cta_cliente
             into v_ind_rub_debito, v_tra_con_debito, v_mod_con_debito, v_mad_con_debito,
                  v_cod_rub_debito, v_nro_cta_cliente
             from cc_cta_ficticias
            where nro_cuenta = v_nro_cta_debito;
           v_nro_cta_debito := null;
           if v_cod_rub_debito is null and v_nro_cta_cliente is not null then
              v_nro_cta_debito := v_nro_cta_cliente;
              v_ind_rub_debito := 'N';
           end if;
         Exception
           When NO_DATA_FOUND then
             v_ind_rub_debito := 'N';
         End;
     end if;
     v_nro_cta_cliente   := null;
     if to_number(p_cod_bco_credito) = 7 then
         Begin
             select 'S', cod_transaccion, cod_modulo, cod_modalidad, cod_rubro, nro_cta_cliente
               into v_ind_rub_credito, v_tra_con_credito, v_mod_con_credito, v_mad_con_credito,
                    v_cod_rub_credito, v_nro_cta_cliente
               from cc_cta_ficticias
              where nro_cuenta = v_nro_cta_credito;
             v_nro_cta_fic_cre := v_nro_cta_credito;
             v_nro_cta_credito := null;
             if v_cod_rub_credito is null and v_nro_cta_cliente is not null then
                v_nro_cta_credito := v_nro_cta_cliente;
                v_ind_rub_credito := 'N';
             end if;
             if v_mod_con_credito = 5 then
                -- es pago de tarjetas del Banco
                If to_number(p_tip_operacion) in (72,0) and ( substr(p_negocio,1,5) in ('90077','00607') or
                   substr(p_negocio,1,3) = '607' ) then
                   -- infonet cobranzas de tarjetas del Banco
                   if substr(p_negocio,1,5) in ('90077','00607') then -- JIRA 1675
                      vp_nro_tarjeta := substr(p_negocio,6,16);
                      if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
                         v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
                         v_negocio := replace(p_negocio,vp_nro_tarjeta,v_nro_tarjeta);
                      end if;
                   elsif substr(p_negocio,1,3) = '607' then
                     v_nro_tarjeta := substr(p_negocio,4,16);
                     if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
                        v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
                        v_negocio := replace(p_negocio,vp_nro_tarjeta,v_nro_tarjeta);
                     end if;
                   end if;
                elsif to_number(p_tip_operacion) in (72) and to_number(p_nro_atm) > 0 and p_cod_bco_credito = 7 then
                   -- infonet cobranzas de tarjetas del Banco
                   vp_nro_tarjeta := substr(p_negocio,22,16);
                   if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
                     v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
                     v_negocio := replace(p_negocio,vp_nro_tarjeta,v_nro_tarjeta);
                   end if;
                elsif to_number(p_tip_operacion) in (72) and to_number(p_nro_atm) > 0 and p_cod_bco_credito != 7 then -- CANOSTDD-2 -- 06/2017 --
                   -- infonet cobranzas de tarjetas de otro Banco
                   vp_nro_tarjeta := substr(p_negocio,22,16);
                   declare
                     v_nro number;
                   begin
                     select to_number(vp_nro_tarjeta) into v_nro from dual;
                   exception
                     when others then
                       vp_nro_tarjeta := null;
                   end;
                   if vp_nro_tarjeta is not null then
                     v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
                     v_negocio := replace(p_negocio,vp_nro_tarjeta,v_nro_tarjeta);
                   end if;
                 elsif to_number(v_nro_cta_credito) = 6000002 and p_cod_bco_credito = 7 then -- 6000002 = cta ficticia para tarjeta prepaga
                    -- pago de tarjeta prepaga
                    vp_nro_tarjeta := substr(p_dat_adicional,6,16);
                    if vp_nro_tarjeta is not null then -- CANOSTDD-2 -- 06/2017 --
                       v_nro_tarjeta := lf_nro_tarjeta(vp_nro_tarjeta);
                       v_negocio := replace(p_negocio,vp_nro_tarjeta,v_nro_tarjeta);
                     end if;
                 End if;


                begin
                    select b.nro_cuenta, b.cod_oficina, b.cod_modalidad
                      into v_nro_cta_tarjeta, v_ofi_con_credito, v_mad_con_credito
                      from ge_cuentas b, ta_tarjetas a
                     where a.nro_tarjeta = v_nro_tarjeta
                       and b.nro_cuenta = a.nro_cuenta
                       and rownum = 1;
                exception
                  when others then
                     v_nro_cta_tarjeta := null;
                end;
             end if;
         Exception
             When NO_DATA_FOUND then
                v_ind_rub_credito := 'N';
         End;
     end if;
           -- Hace las verificaciones si el clte de credito es nuestro....
      If nvl(to_number(v_nro_cta_credito),0) != 0 and nvl(v_actualiza, 'N') = 'S' Then
          -- Obtiene los datos de la cuenta de credito...
          If v_nro_cta_credito is not null then
            lp_dat_cta(v_nro_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre);
            pag_cta.PR_OBT_CUENTA(v_nro_cta_credito);
            g_cod_error := pag_cta.G_COD_ERROR;
            v_est_cta_cre := pag_cta.FU_OBT_EST_CUENTA;
          Else
            v_mon_cta_cre := v_cod_moneda;
            v_mod_cta_cre := v_mod_cta_deb;
            v_mad_cta_cre := v_mad_cta_deb;
            v_ofi_cta_cre := v_ofi_origen;
          End if;
          if g_cod_error = 12 Then -- Cuenta inexistente
             v_actualiza := 'N'; -- Tarjeta desconocida
             p_det_error := 'Tarjeta Desconocida.';
          end if;
          If v_mon_cta_cre != v_cod_moneda and nvl(v_actualiza, 'N') = 'S' then
             -- Se responde que la cuenta no existe...
            v_actualiza := 'N';
            p_det_error := 'No se encuentra la cuenta de crédito.';
          End if;

          --WA:31/07/2014 Se ajusta inferior para igualar a funcionamiento anterior
          if (v_est_cta_cre not in ('N', 'S', 'I') or v_mad_cta_cre not in (31,41,42,48,46,49)) and  nvl(v_actualiza, 'N') = 'S'  Then -- No es normal o con bloqueo de saldo
             -- Estado Inactiva tambien debe permitir.
             v_actualiza := 'N'; -- Transaccion no aprobada
             p_det_error := 'Estado de cuenta no permitido.';
          end if;
      End If;


       --Valida Transacciones de Infonet Cobranzas de entidades públicas, donde el Banco facturador es BBVA
     if v_ind_rub_credito = 'S' Then
       begin
          v_cod_rub_facturador := fue_obt_val_max_refcodes('COD_RUB_FACTURADOR', nvl(v_nro_cta_credito,v_nro_cta_fic_cre));
       exception
          when others then
            v_cod_rub_facturador := nulL;
       end;
       if v_cod_rub_facturador is not null then
          v_ind_acr_batch := 'S';
       else
          v_ind_acr_batch := 'N';
       end if;
     else
       v_ind_acr_batch := 'N';
     end if;

     --Ver si la cuenta está configurada para comisión
     begin
       select distinct 'S'
         into v_ind_obt_comision
         from ba_cod_referencias
        where dominio = 'NRO_CTA_COM_BANCARD'
          and val_minimo = v_nro_cta_fic_cre;
     exception
        when others then
          v_ind_obt_comision := 'N';
     end;

     if p_tip_operacion in (72, '00' ) and nvl(p_mto_comision,0) <> 0 and nvl(v_ind_obt_comision, 'N') = 'S' then
          --valido que exista la cuenta de bancard de cobro de comisiones por la operacion 72, en la moneda de la operación.
          v_cta_com_bancard := fue_obt_val_max_refcodes('NRO_CTA_COM_BANCARD', nvl(v_nro_cta_credito, v_nro_cta_fic_cre)) ;

          if v_cta_com_bancard is null then
             v_actualiza := 'N';
             p_det_error := 'No se encuentra el número de Cuenta de Comisión de Bancard';
          end if;

          if v_mon_cta_cre <> 'GS' then
             v_actualiza := 'N';
             p_det_error := 'La operación debe ser en GS.';
          end if;

          begin
            select cod_modulo, cod_modalidad, cod_oficina
              into v_cod_mod_com_ban, v_cod_mad_com_ban, v_cod_ofi_comision
              from ge_cuentas
             where nro_cuenta = v_cta_com_bancard;
          exception
            when others then
              v_actualiza := 'N';
              p_det_error := 'No se encuentra el número de Cuenta de Comisión de Bancard';
          end;
          if v_cod_mod_com_ban = 4 then
             begin
               select estado
                 into v_est_cta_com_ban
                 from cc_cta_corrientes
                where nro_cuenta = v_cta_com_bancard;
              exception
                 when others then
                   v_actualiza := 'N';
                   p_det_error := 'No se encuentra estado de la Cuenta de Comisión de Bancard';
              end;
           else
              begin
                select estado
                  into v_est_cta_com_ban
                  from ah_cta_vistas
                 where nro_cuenta = v_cta_com_bancard;
              exception
                 when others then
                    v_actualiza := 'N';
                    p_det_error := 'No se encuentra estado de la Cuenta de Comisión de Bancard';
              end;
            end if;
            if p_monto <= p_mto_comision then
               v_actualiza := 'N';
               p_det_error := 'El monto no puede ser mayor a la comisión';
         end if;
     else
          v_ind_obt_comision := 'N';
     end if;
     if nvl(to_number(v_nro_cta_debito),0) != 0 and nvl(v_actualiza, 'S') = 'S' Then
      -- Debo verificar si existe la cuenta
      If v_ind_rub_debito = 'N' then
         pag_cta.PR_OBT_CUENTA(v_nro_cta_debito);
         v_est_cuenta := pag_cta.FU_OBT_EST_CUENTA;
         v_cod_persona    := PAG_CTA.G_CTAS.cod_cliente;
         v_nro_cta_combinada := pag_cta.G_CTAS.nro_cta_combinada;
         v_sal_dis_debito    := pag_cta.FU_SAL_DISPONIBLE;
         if pag_cta.G_CTAS.cod_modalidad = 41 then
            v_sal_dis_debito := v_sal_dis_debito + PAG_CTA.FU_OBT_LIN_SOBREGIRO(v_nro_cta_debito,v_fec_actual);
         end if;
      Else
         pag_cta.g_ctas.sal_disponible := 0;
         pag_cta.g_ctas.sal_actual     := 0;
      End if;
      lp_dat_cta(v_nro_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb);
      g_cod_error := pag_cta.G_COD_ERROR;
      if g_cod_error = 12 Then -- Cuenta inexistente
         v_actualiza := 'N'; -- Tarjeta desconocida
         p_det_error := 'No se encuentra la cuenta de Débito.';
      end if;
   end if;

     --inserta movimiento
   if nvl(v_actualiza, 'S') = 'S' then
    if nvl(to_number(v_nro_cta_debito),0) != 0 or v_ind_rub_debito = 'S' then
          -- Carga los parametros de movimientos de Debito
         v_nro_secuencia := v_nro_secuencia + 1;
         r_gmovi.cod_modulo      := v_mod_cta_deb;
         r_gmovi.cod_modalidad   := v_mad_cta_deb;
         r_gmovi.cod_oficina     := nvl(v_ofi_cta_deb,v_ofi_origen);
         r_gmovi.nro_cuenta      := v_nro_cta_debito;
         r_gmovi.cod_moneda      := nvl(v_mon_cta_deb, v_cod_moneda);
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_actual;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := p_cod_tra_padre;
         r_gmovi.cod_mod_padre   := p_cod_mod_padre;
         r_gmovi.cod_mad_padre   := p_cod_mad_padre;
         If v_ind_rub_debito = 'S' then
           r_gmovi.cod_transaccion := v_tra_con_debito;
           r_gmovi.tip_mov_rubro   := 'D';
           r_gmovi.cod_rubro       := v_cod_rub_debito;
         Else
             r_gmovi.cod_transaccion := 503;
             If lf_exi_banco(v_cod_bco_credito) = 'S' then
                --WA:06/08/2014 si es financiera se deja Nulo el Cod_banco
                -- r_gmovi.cod_banco       := vp_bco_credito;
                if lf_exi_financiera(v_cod_bco_credito) = 'S' then
                   r_gmovi.cod_banco       := null;
                else
                   r_gmovi.cod_banco       := v_cod_bco_credito;
                end if;
             End if;

         End if;
         r_gmovi.monto           := v_imp_debito;
         r_gmovi.nro_documento   := p_nro_documento;
         r_gmovi.nro_documento2  := p_nro_atm;
         r_gmovi.referencia      := v_nro_cta_credito;
         r_gmovi.nro_documento3  := p_nro_doc_infonet;

         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_debito;
         r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen  := v_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'Proceso Extorno ' || p_nro_doc_infonet;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_persona     := v_cod_persona;

         lp_ins_ge_movimiento;
         r_gmovi.tip_mov_rubro   := null;
         r_gmovi.cod_rubro       := null;
         -- cuenta combinada ----------------------------------

         if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            IF v_sal_dis_debito < 0 then
               r_gmovi.monto           := v_imp_debito;
            else
               r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
            end if;
            r_gmovi.concepto        := 'Transferencia de la Cta '||v_nro_cta_combinada;
            r_gmovi.cod_tra_padre   := 309;
            r_gmovi.cod_transaccion := 602;
            ---
            lp_ins_ge_movimiento;
            -- acredito el monto que le falta
            lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb, v_nro_cta_debito, r_gmovi.monto * -1);
         end if;

         lp_upd_cta_debito(v_mod_cta_deb, v_mad_cta_deb, v_nro_cta_debito, v_imp_debito);

         if v_mad_cta_deb in (42,46,49) then
            lp_upd_cta_ban(v_mad_cta_deb, v_nro_cta_debito, v_imp_debito*-1);
         end if;

         If v_est_cuenta in ('I', 'A') AND g_cod_error = 00 Then -- Debo cambiar el estado de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto := null;
            r_gmovi.est_cuenta := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            lp_ins_ge_movimiento;
         End If;

         if v_nro_cta_combinada is not null and v_imp_debito > v_sal_dis_debito then
            IF v_sal_dis_debito < 0 then
               r_gmovi.monto           := v_imp_debito;
            else
               r_gmovi.monto           := v_imp_debito - v_sal_dis_debito;
            end if;
            pag_cta.PR_OBT_CUENTA(v_nro_cta_combinada);
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.concepto        := 'Transferencia a la Cta '||v_nro_cta_debito;
            r_gmovi.cod_tra_padre   := 309;
            r_gmovi.cod_transaccion := 503;
            r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
            r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
            r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
            r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
            ---
            lp_ins_ge_movimiento;

            --DYDMR-2055: ITGF - Saldo de Cuenta 0102194039 SC 17595
            lp_upd_cta_debito(pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,
                              pag_cta.g_ctas.nro_cuenta, r_gmovi.monto);

            --FB AP 927 Actualizo el estado de la cta.comb.
            v_est_cta_comb := pag_cta.FU_OBT_EST_CUENTA;
            IF v_est_cta_comb = 'I' AND g_cod_error = 00 then
                v_nro_secuencia := v_nro_secuencia + 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.monto := null;
                r_gmovi.est_cuenta := 'N';
                r_gmovi.cod_tra_padre   := 425;
                r_gmovi.cod_transaccion := 425;
                lp_ins_ge_movimiento;
            END IF;
         end if;
      End if;

      --Carga los parametros de movimientos de Credito
      v_nro_secuencia := v_nro_secuencia + 1;
      r_gmovi.cod_modulo      := v_mod_cta_cre;
      r_gmovi.cod_modalidad   := v_mad_cta_cre;
      r_gmovi.cod_oficina     := nvl(v_ofi_cta_cre,v_ofi_origen);
      r_gmovi.nro_cuenta      := v_nro_cta_credito;
      r_gmovi.cod_moneda      := nvl(v_mon_cta_cre, v_cod_moneda);
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      --
      r_gmovi.fec_valor       := v_fec_valor;
      r_gmovi.cod_tra_padre   := p_cod_tra_padre;
      r_gmovi.cod_mod_padre   := p_cod_mod_padre;
      r_gmovi.cod_mad_padre   := p_cod_mad_padre;
      r_gmovi.cod_transaccion := 602;
      If lf_exi_banco(p_cod_bco_credito) = 'S' then
         if lf_exi_financiera(p_cod_bco_credito) = 'S' then
            r_gmovi.cod_banco       := null;
         else
            r_gmovi.cod_banco       := p_cod_bco_credito;
         end if;
      End if;

      If v_ind_rub_credito = 'S' then
         r_gmovi.cod_transaccion := v_tra_con_credito;
         if v_cod_rub_credito is not null then
           r_gmovi.tip_mov_rubro   := 'C';
           r_gmovi.cod_rubro       := v_cod_rub_credito;
         end if;
         r_gmovi.cod_modulo      := v_mod_con_credito;
         r_gmovi.cod_modalidad   := v_mad_con_credito;
         if v_nro_cta_tarjeta is not null then
            r_gmovi.cod_oficina     := v_ofi_con_credito;
            r_gmovi.nro_cuenta      := v_nro_cta_tarjeta;
         end if;
      end if;

      if nvl(v_ind_obt_comision, 'N') = 'S' then
         v_imp_credito := v_imp_credito - v_mto_comision;
         r_gmovi.monto := v_imp_credito;
      else
         r_gmovi.monto := v_imp_credito;
      end if;

      r_gmovi.nro_documento   := p_nro_documento;
      r_gmovi.nro_documento2  := p_nro_atm;
      r_gmovi.nro_documento3  := p_nro_doc_infonet;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;

      -- tys: cotizacion de cambio
      r_gmovi.cotizacion      := v_cot_credito;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * r_gmovi.cotizacion);
      --
      r_gmovi.cod_ofi_origen  := v_ofi_origen;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Proceso Extorno ' || p_nro_doc_infonet;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_persona     := v_cod_persona;
      lp_ins_ge_movimiento;
      r_gmovi.tip_mov_rubro   := null;
      r_gmovi.cod_rubro       := null;
      lp_upd_cta_credito;
      if v_mad_cta_cre in (42,46,49) then
         lp_upd_cta_ban(v_mad_cta_cre, v_nro_cta_credito, v_imp_credito);
      end if;
      If  v_est_cta_cre in ('I', 'A') AND g_cod_error = 00 Then -- Debo cambiar el estado de la cuenta
         v_nro_secuencia := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.monto := null;
         r_gmovi.est_cuenta := 'N';
         r_gmovi.cod_tra_padre   := 425;
         r_gmovi.cod_transaccion := 425;
         lp_ins_ge_movimiento;
      End If;

      -- Se realiza el crédito por la comisión a bancard.
      IF nvl(v_ind_obt_comision, 'N') = 'S' then
         v_nro_secuencia := v_nro_secuencia + 1;
         r_gmovi.cod_modulo      := v_cod_mod_com_ban;
         r_gmovi.cod_modalidad   := v_cod_mad_com_ban;
         r_gmovi.cod_oficina     := nvl(v_cod_ofi_comision                                                                      ,v_ofi_origen);
         r_gmovi.nro_cuenta      := v_cta_com_bancard;
         r_gmovi.cod_moneda      := nvl(v_mon_cta_cre, v_cod_moneda);
         r_gmovi.cod_usuario     := v_cod_usuario;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fec_actual;
         r_gmovi.nro_secuencia   := v_nro_secuencia;

         r_gmovi.fec_valor       := v_fec_valor;
         r_gmovi.cod_tra_padre   := p_cod_tra_padre;
         r_gmovi.cod_mod_padre   := p_cod_mod_padre;
         r_gmovi.cod_mad_padre   := p_cod_mad_padre;
         r_gmovi.cod_transaccion := 602;
         r_gmovi.monto           := v_mto_comision;

         r_gmovi.nro_documento   := p_nro_documento;
         r_gmovi.nro_documento2  := p_nro_atm;
         r_gmovi.nro_documento3  := p_nro_doc_infonet;

         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion      := v_cot_credito;
         --
         r_gmovi.cod_ofi_origen  := v_ofi_origen;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'Proceso Extorno ' || p_nro_doc_infonet;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_persona     := 149064;

         lp_ins_ge_movimiento;
         --actualización de saldo cuenta bancard.
         If nvl(v_actualiza, 'S') = 'S' then
            --Mejoras ATM DE-2209--Punto 3: No Bloquear la Cuenta de Crédito cuando sea Cuenta Bancaria
            ------------------------------------------------------------------------------------------
            --Mejoras ATM DE-2209--Punto 2: Realizar 3 intentos para bloqueo de la Cuenta de Credito
            --cuando es de modalidad 41-Cuenta Corriente o 31-Caja de Ahorro.
            --Solo posterior a ello generar el error 19-Reintente
            ------------------------------------------------------------------------------------------
            for v_can_int_bloqueo in 1..20 loop
                IF PAG_CTA.FU_LLAVEAR_CUENTA(v_cod_mad_com_ban, v_cta_com_bancard, 'N') = 'N' Then
                   if v_can_int_bloqueo = 20 then
                      v_actualiza := 'N';
                      p_det_error := 'Llaveo de Cuenta de Comisión Bancard.';
                      exit;
                   end if;
                else
                   exit;
                end if;
            end loop;
         End if;

         IF nvl(v_actualiza, 'N') = 'S' THEN
           If v_cod_mad_com_ban = 31 then
              update ah_cta_vistas
                 set sal_total = nvl(sal_total, 0) + v_mto_comision,
                     estado = decode(estado, 'I', 'N', estado)
               where nro_cuenta = v_cta_com_bancard;
           elsif v_cod_mad_com_ban = 41 then
              update cc_cta_corrientes
                 set sal_total = nvl(sal_total, 0) + v_mto_comision,
                     estado = decode(estado, 'I', 'N', 'A', 'N', estado)
               where nro_cuenta = v_cta_com_bancard;
           End if;
         END IF;

         If v_est_cta_com_ban in ('I', 'A')AND g_cod_error = 00 Then -- Debo cambiar el estado de la cuenta
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto := null;
            r_gmovi.est_cuenta := 'N';
            r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            lp_ins_ge_movimiento;
         End If;
       end if;
         if p_cod_tra_padre = 381 then
           begin
              update GE_OPE_EXT_EFE_POS
                 set extornado = 'S'
               where nro_transaccion = p_nro_doc_infonet;
            exception
              when others then
                v_actualiza := 'N';
                p_det_error := 'No se encuentra la operación de Vuelto.';
            end;
         end if;
       end if;
       if nvl(v_actualiza, 'S') = 'S' then
          lp_ins_log_extornos;
       end if;
     END;
     IF nvl(v_actualiza, 'S') = 'S' then
        COMMIT;
     else
        ROLLBACK;
     END IF;
     p_actualiza := v_actualiza;
EXCEPTION
   WHEN OTHERS THEN
      rollback;
      p_actualiza := 'N';
      p_det_error := sqlerrm;
END prg_rev_inf_cobranza;
/

