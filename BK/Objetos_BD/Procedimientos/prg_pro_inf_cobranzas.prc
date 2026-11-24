CREATE OR REPLACE PROCEDURE IT.PRG_PRO_INF_COBRANZAS (p_tip_proceso varchar2 default 'C') is
/*  Procesa los movimientos liberado de infonet cobranzas. tiene 2 partes:
    1. procesa reversado movimientos del dia para contabilizar
    2. Procesa reversado movimientos luego de 48 Hs para el debito y credito respectivo
*/
---
v_fec_actual   date := pag_cal.FU_OBT_FEC_ACTUAL(3);
v_fec_proceso  date;
v_cod_oficina  number(4) := fug_obt_pardinamico('COD_OFI_GEN_INF');
v_nro_secuencia number(4);
v_hora         varchar2(8);
v_mto_credito  ge_movimientos.monto%type;
v_con_mov_com_bancard ge_movimientos.concepto%type := fug_obt_pardinamico('CON_MOV_COM_BANCARD');
v_fec_imp_acr_bat date := to_date(fug_obt_pardinamico('ICB_FEC_IMP_ACR_BAT'), 'dd/mm/Yyyy');
v_cod_rub_cta_fic cb_rubros.cod_rubro%type;



R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
---
function lf_obt_cob_rubro(p_cod_modulo in number, p_cod_modalidad in number, p_cod_transaccion in number,p_cod_moneda in varchar2,p_tip_movimiento in varchar2)
return varchar2 is
v_cod_rubro varchar2(20);
begin
  select cod_rubro
    into v_cod_rubro
    from ge_tip_asientos b, ge_transacciones a
   where a.cod_modulo = p_cod_modulo
     and a.cod_modalidad = p_cod_modalidad
     and a.cod_transaccion = p_cod_transaccion
     and b.cod_tip_asiento = a.cod_tip_asiento
     and b.cod_moneda = p_cod_moneda
     and (b.cod_sec_contable = 'X' or b.cod_sec_contable is null)
     and b.tip_movimiento = p_tip_movimiento;
  return v_cod_rubro;
end;
--- recupera los datos de la cuenta ficticia
procedure lp_obt_cta_ficticia(p_nro_cuenta      in ge_cuentas.nro_cuenta%type,
                              p_nro_tarjeta     in ta_tarjetas.nro_tarjeta%type,
                              p_cod_modulo      out ge_cuentas.cod_modulo%type,
                              p_cod_modalidad   out ge_cuentas.cod_modalidad%type,
                              p_cod_oficina     out ge_cuentas.cod_oficina%type,
                              p_nro_cta_tarjeta out ge_cuentas.nro_cuenta%type,
                              p_cod_rubro       out cb_rubros.cod_rubro%type) is
Begin
   select cod_modulo, cod_modalidad, cod_rubro
     into p_cod_modulo, p_cod_modalidad, p_cod_rubro
     from cc_cta_ficticias
    where nro_cuenta = p_nro_cuenta;
   if p_nro_tarjeta is not null and p_cod_modulo = 5 then
      --Si es una tarjeta, busco la cuenta de la tarjeta
     begin
      select a.nro_cuenta
        into p_nro_cta_tarjeta
        from ta_tarjetas a
       where a.nro_tarjeta = p_nro_tarjeta
         and rownum = 1;

         --Recuperar datos de la cuenta de la tarjeta
            pag_cta.pr_obt_cuenta(p_nro_cta_tarjeta);
            p_cod_modulo    := pag_cta.g_ctas.cod_modulo;
            p_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
            p_cod_oficina   := pag_cta.g_ctas.cod_oficina;
         ---
      Exception
        WHEN NO_DATA_FOUND THEN
           null; -- NO DEBE CAER, SE DEJA EN NULO HASTA SE VERIFIQUE EL MOTIVO POR EL QUE SE ESTÁ INSERTANDO MAL EL NRO_TARJETA - JS 11/06/13
           -- raise_application_error(-20000,'Error tarjeta inexistente: '|| p_nro_tarjeta);
      end;
      /* no corresponde, siempre va dar CUENTA INEXISTENTE, YA QUE LAS FICTICIAS NO EXISTEN EN GE_CTA_CLIENTES - JS 11/06/13 */
      --Recuperar datos de la cuenta
     /* pag_cta.pr_obt_cuenta(p_nro_cuenta);
      p_cod_modulo    := pag_cta.g_ctas.cod_modulo;
      p_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
      p_cod_oficina   := pag_cta.g_ctas.cod_oficina; */
   end if;
Exception
  WHEN NO_DATA_FOUND THEN
     --Si no encuentra en ficticia, colocar la modalidad de la cuenta
     pag_cta.pr_obt_cuenta(p_nro_cuenta);
     p_cod_modulo    := pag_cta.g_ctas.cod_modulo;
     p_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
     p_cod_oficina   := pag_cta.g_ctas.cod_oficina;
     IF pag_cta.fu_obt_cod_error() <> 0 THEN
        raise_application_error(-20000,'Error al verificar cta.: ' ||p_nro_cuenta || ' ' ||pag_cta.g_cod_error||'-'||pag_cta.g_msj_error);
     END IF;
  WHEN OTHERS THEN
     raise_application_error(-20000,'Error en lp_obt_cta_ficticia: ' || SQLERRM);
end;
-- obtiene la fecha de proceso
function lf_obt_fec_proceso(p_fecha in date)
return date is
v_retorno date := p_fecha;
begin
  for i in 1..2
  loop
    v_retorno := pag_cal.fu_obt_fec_habil(v_retorno-1,-1, 1);
  end loop;
  return v_retorno;
end;

--- genera el movimiento contable por la transaccion generada a traves de infonet cobranzas
PROCEDURE lp_gen_mov_contable IS
        CURSOR cuentas IS
        SELECT nro_cta_debito,nro_cta_credito,cod_moneda,monto,
               fecha,hora,to_char(nro_documento) nro_documento,
               nro_tarjeta,
               rowid fila
          FROM ge_mov_inf_cobranzas
         WHERE liberado = 'N'
           AND reversado = 'N'
           AND fecha = v_fec_actual;
        --
        v_cod_mon_credito varchar2(03) := pag_gen.FU_OBT_MON_LOCAL;
        v_cod_tra_credito NUMBER(03)   := 996; -- credito tarjetas bancard
        --
        v_cod_mod_credito NUMBER(03);
        v_cod_mad_credito NUMBER(03);
        --
        v_nro_documento NUMBER(15);
        v_nro_documento3 NUMBER(15);

        v_cod_ofi_credito number(5);
        v_nro_cta_tarjeta varchar2(20);


        v_lugar    VARCHAR2(300);
      BEGIN
        ---------------------------------------------------------------------
        -- Esta operacion toma reversado movimientos de pago que se generan
        -- diariamente en reversado comercios, y que fueron enviados a traves de
        -- Infonet para generar un movimiento que afectara a las cuentas
        -- contables relacionadas
        -- La transaccion genera
        -- debito.: a la cuenta Infonet Cobranzas (cuenta puente)
        -- credito: a la cuenta Deudores de Tarjetas
        ---------------------------------------------------------------------
        v_nro_secuencia := 0;
        FOR CC IN cuentas LOOP
          v_nro_documento3 := cc.nro_documento;
          IF LENGTH(cc.nro_documento) > 7 THEN
            v_nro_documento := SUBSTR(cc.nro_documento,-7,7);
          ELSE
            v_nro_documento := cc.nro_documento;
          END IF;
          v_lugar := 'Procesando.... Debito a: '||cc.nro_cta_debito||
                     '  Credito a: '||cc.nro_cta_credito;
          lp_obt_cta_ficticia( cc.nro_cta_credito, cc.nro_tarjeta, v_cod_mod_credito, v_cod_mad_credito,
                               v_cod_ofi_credito, v_nro_cta_tarjeta, v_cod_rub_cta_fic );
          IF v_cod_mod_credito = 5  THEN
            -------------------------------------------------------------
            -- La cuenta que viene en el credito es la cuenta operativa
            -- que es una cuenta ficticia. Se debe generar un movimiento
            -- con la transaccion 996 para Bancard.......................
            -------------------------------------------------------------
            if v_nro_secuencia > 990 then
              --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
              v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
              v_nro_secuencia := 0;
            end if;
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_modulo    := v_cod_mod_credito;
            r_gmovi.cod_modalidad := v_cod_mad_credito;
            r_gmovi.cod_oficina   := nvl(v_cod_ofi_credito,v_cod_oficina);
            r_gmovi.nro_cuenta    := v_nro_cta_tarjeta;
            r_gmovi.cod_moneda    := v_cod_mon_credito;
            r_gmovi.fecha         := v_fec_actual;
            r_gmovi.fec_valor     := v_fec_actual;
            r_gmovi.cod_tra_padre := v_cod_tra_credito;
            r_gmovi.cod_transaccion := v_cod_tra_credito;
            r_gmovi.nro_documento := v_nro_documento;
            r_gmovi.nro_documento3 := v_nro_documento3;
            r_gmovi.monto         := cc.monto;
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := v_cod_oficina;
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := v_cod_mod_credito;
            r_gmovi.cod_mad_padre := v_cod_mad_credito;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          END IF;
        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20000,'Error al procesar cobr. diarias: '||v_lugar || SQLERRM);
      END;
      -- PROCESO A LAS 48 HORAS DE LA OPERACION
      PROCEDURE lp_deb_pendientes IS
        --v_fec_proceso DATE;
        CURSOR cuentas IS
        SELECT nro_cta_debito,nro_cta_credito,cod_moneda,monto, nvl(mto_comision, 0) mto_comision,
               fecha,hora,to_char(nro_documento) nro_documento,
               nro_tarjeta, cod_tra_padre, hor_referencia, -- CANOSTDD-2 -- 01/2017 --
               rowid fila
          FROM ge_mov_inf_cobranzas i
         WHERE liberado = 'N'
           AND reversado = 'N'
           AND fecha <= v_fec_proceso
           AND nvl(p_tip_proceso, 'C') = 'C'
           AND not exists (select 1 from ba_cod_referencias 
                            where dominio = 'NRO_CTA_REL_SET_BANCARD'
                              and val_maximo = i.nro_cta_credito)
           --Se excluyen las cuentas de acreditación en batch - COREESSAP-20 ESSAP - Créditos por lotes y conciliación de trns.
           AND ( v_fec_imp_acr_bat + 10 >= v_Fec_actual or
                 not exists ( select nro_cuenta from cc_cta_ficticias c, ba_cod_referencias b
                             where c.cod_rubro = b.val_minimo
                               and c.nro_cuenta = i.nro_cta_credito
                               and b.dominio = 'ICB_NRO_CTA_BATCH'))
       UNION ALL
       SELECT nro_cta_debito,nro_cta_credito,cod_moneda,monto, nvl(mto_comision, 0) mto_comision,
               fecha,hora,to_char(nro_documento) nro_documento,
               nro_tarjeta, cod_tra_padre, hor_referencia, -- CANOSTDD-2 -- 01/2017 --
               rowid fila
          FROM ge_mov_inf_cobranzas i
         WHERE liberado = 'N'
           AND reversado = 'N'
           AND trunc(nvl(fec_referencia, fec_insercion)) <= v_fec_proceso
           AND nvl(p_tip_proceso, 'C') = 'S'
           AND exists (select 1 from ba_cod_referencias 
                        where dominio = 'NRO_CTA_REL_SET_BANCARD'
                          and val_maximo = i.nro_cta_credito);

        --
        v_cod_tra_padre  number(3); -- := 227;  -- CANOSTDD-2 -- 01/2017 --
        --
        v_cod_mon_debito varchar2(03);
        v_cod_tra_debito NUMBER(03);
        --
        v_cod_mon_credito varchar2(03);
        v_cod_mod_credito number(3);
        v_cod_mad_credito number(3);
        v_cod_tra_credito NUMBER(03);
        --
        v_nro_documento NUMBER(15);
        v_nro_documento3 NUMBER(15);
        v_msj_error VARCHAR2(200);
        --
        v_es_ficticia VARCHAR2(1);
        --
        v_lugar varchar2(200);
        --
        v_cod_modulo number(4);
        v_cod_modalidad number(4);
        v_cod_mod_com number(4);
        v_cod_mad_com number(4);
        v_nvo_estado varchar2(1);
        v_nvo_est_com varchar2(1);
        v_sal_disponible number(18,2);
        v_sal_dis_com number(18,2);
        v_procesa varchar2(1);
        v_pro_com varchar2(1);
        v_cod_ofi_credito number(5);
        v_nro_cta_tarjeta varchar2(20);
        --v_nro_cta_credito ge_movimientos.nro_cuenta%type;
        v_cta_com_bancard ge_cuentas.nro_cuenta%type;
        v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
        v_nro_cta_facturador ge_par_dinamicos.val_parametro%type := fug_obt_parentes(112,'NRO_CTA_FACTURADOR');
        v_ind_obt_comision varchar2(1) := 'N';
        v_cta_deb_icb cc_cta_ficticias.nro_cuenta%type := fug_obt_pardinamico('ICB_CTA_TRA_DEB');
      BEGIN
        v_fec_proceso := lf_obt_fec_proceso(v_fec_actual);
        v_nro_secuencia := 0;
      FOR CC IN cuentas LOOP
          v_msj_error      := NULL;
          v_es_ficticia := 'N';
          --
          if v_nro_secuencia > 990 then
            --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
            v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
            v_nro_secuencia := 0;
          end if;
          -- calculo el numero de documento -----------------------------
          IF LENGTH(cc.nro_documento) > 7 THEN
            v_nro_documento := SUBSTR(cc.nro_documento,-7,7);
          ELSE
            v_nro_documento := cc.nro_documento;
          END IF;
          v_nro_documento3 := cc.nro_documento;
          --
          v_lugar := 'Procesando.... Debito a: '||cc.nro_cta_debito||
                  '  Credito a: '||cc.nro_cta_credito;
          -- verifico si la cuenta de debito puede recibir debito --------
          v_cod_tra_credito := 602;
          v_cod_tra_debito  := 503;
          ---
          -- CANOSTDD-2 -- 01/2017 -- Asignar el codigo de transaccion padre
          v_cod_tra_padre := nvl(cc.cod_tra_padre,227);
          --
          pag_cta.PR_VER_OPERACION(cc.nro_cta_debito,v_cod_tra_padre,4,41,'D',
                                   cc.cod_moneda,cc.monto,v_cod_oficina,
                                   v_cod_modulo, v_cod_modalidad, v_nvo_estado,
                                   v_sal_disponible,v_procesa,v_cod_tra_debito);
          v_cod_mon_debito := pag_cta.g_CTAS.COD_MONEDA;
          if v_procesa = 'N' then
             v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
          end if;
          IF v_msj_error IS NULL THEN   /* verifico cuenta credito */
            --
            v_lugar := 'Obtiendo cuenta ficticia '||cc.nro_cta_credito;
            lp_obt_cta_ficticia (cc.nro_cta_credito, cc.nro_tarjeta, v_cod_mod_credito, v_cod_mad_credito,
                                 v_cod_ofi_credito, v_nro_cta_tarjeta, v_cod_rub_cta_fic );
            IF v_cod_mod_credito = 5  THEN
              v_es_ficticia := 'S';
              --------------------------------------------------------------
              -- Cuando la cuenta credito del movimiento Infonet es una
              -- cuenta operativa (ficticia), se debe realizar un credito
              -- a la cuenta contable deudora de cada procesadora
              -- Buscar la cuenta relacionada segun el tipo de asiento para
              -- generar una linea en FGDIARI con la cuenta contable
              --------------------------------------------------------------
              v_cod_tra_credito := 996; -- credito tarjetas bancard
              v_cod_mon_credito := v_cod_mon_local;
              --
                -- procesar la cuenta de debito que acompana a la cuenta
                -- operativa (ficticia )
                -- debito a la cuenta de debito
                pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_documento3);
                pag_cta.pr_act_operacion(cc.nro_cta_debito,
                                         v_hora,
                                         'D',
                                         cc.cod_moneda,
                                         cc.monto,
                                         v_cod_tra_padre,
                                         v_cod_tra_debito,
                                         v_nro_documento,
                                         null,
                                         v_cod_oficina,
                                         4,
                                         41,
                                         null,
                                         null,
                                         'Infonet Cobranza',
                                         'N',
                                         v_nro_secuencia,
                                         v_fec_actual);
                if pag_cta.g_cod_error <> 0 then
                   -- actualizacion con problemas
                   v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                Elsif cc.monto <> 0 then /*FB. 04.06.2010 No generar movimientos con monto 0*/
                  ------------------------------------------
                  -- Movimiento correspondiente al credito con monto negativo
                  ------------------------------------------
                  v_nro_secuencia := v_nro_secuencia + 1;
                  r_gmovi.cod_usuario   := user;
                  r_gmovi.hora          := v_hora;
                  r_gmovi.nro_secuencia := v_nro_secuencia;
                  r_gmovi.cod_modulo    := v_cod_mod_credito;
                  r_gmovi.cod_modalidad := v_cod_mad_credito;
                  r_gmovi.cod_oficina   := nvl(v_cod_ofi_credito,v_cod_oficina);
                  r_gmovi.nro_cuenta    := v_nro_cta_tarjeta;
                  r_gmovi.cod_moneda    := v_cod_mon_credito;
                  r_gmovi.fecha         := v_fec_actual;
                  r_gmovi.fec_valor     := v_fec_actual;
                  r_gmovi.cod_tra_padre := v_cod_tra_padre;
                  r_gmovi.cod_transaccion := null;
                  r_gmovi.nro_documento := v_nro_documento;
                  r_gmovi.nro_documento3 := v_nro_documento3;
                  r_gmovi.monto         := cc.monto;
                  r_gmovi.estado        := 'N';
                  r_gmovi.cod_ofi_origen := v_cod_oficina;
                  r_gmovi.reversado     := 'N';
                  r_gmovi.emi_aviso     := 'N';
                  r_gmovi.protegido     := 'N';
                  r_gmovi.cod_mod_padre := 4;
                  r_gmovi.cod_mad_padre := 41;
                  r_gmovi.tip_mov_rubro := 'C';
                  r_gmovi.cod_rubro     := lf_obt_cob_rubro(v_cod_mod_credito, v_cod_mad_credito, v_cod_tra_credito,v_cod_mon_credito,'D');
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

                  -- actualizo el registro de ge_mov_inf_cobranzas como procesado ------
                  UPDATE ge_mov_inf_cobranzas
                     SET liberado = 'S'
                   WHERE rowid = cc.fila;
                end if;
            ELSIF cc.nro_cta_credito = v_cta_deb_icb then --CREDITO POR CUENTA FICTICIA DE OPERACIONES EN BATCH QUE NO SE PUDIERON DEBITAR
              v_es_ficticia := 'N';
              v_cod_mon_credito := v_cod_mon_local;
              v_nro_secuencia := v_nro_secuencia + 1;
              r_gmovi.cod_usuario   := user;
              r_gmovi.hora          := v_hora;
              r_gmovi.nro_secuencia := v_nro_secuencia;
              r_gmovi.cod_modulo    := v_cod_mod_credito;
              r_gmovi.cod_modalidad := v_cod_mad_credito;
              r_gmovi.cod_oficina   := nvl(v_cod_ofi_credito,v_cod_oficina);
              r_gmovi.nro_cuenta    := null;
              r_gmovi.cod_moneda    := v_cod_mon_credito;
              r_gmovi.fecha         := v_fec_actual;
              r_gmovi.fec_valor     := v_fec_actual;
              r_gmovi.cod_tra_padre := v_cod_tra_padre;
              r_gmovi.cod_transaccion := null;
              r_gmovi.nro_documento := v_nro_documento;
              r_gmovi.nro_documento3 := v_nro_documento3;
              r_gmovi.monto         := cc.monto;
              r_gmovi.estado        := 'N';
              r_gmovi.cod_ofi_origen := v_cod_oficina;
              r_gmovi.reversado     := 'N';
              r_gmovi.emi_aviso     := 'N';
              r_gmovi.protegido     := 'N';
              r_gmovi.cod_mod_padre := 4;
              r_gmovi.cod_mad_padre := 41;
              r_gmovi.tip_mov_rubro := 'C';
              r_gmovi.cod_rubro     := v_cod_rub_cta_fic;
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

            ELSE
              -- no es una cuenta ficticia, se debe realizar una transferencia
              v_es_ficticia := 'N';
              -- Veo el estado, la moneda y el saldo de la cuenta credito -----
              v_mto_credito := cc.monto;

              --Ver si la cuenta está configurada para comisión
              begin
                 select distinct 'S'
                   into v_ind_obt_comision
                   from ba_cod_referencias
                  where dominio = 'NRO_CTA_COM_BANCARD'
                    and val_minimo = cc.nro_cta_credito;
                exception
                  when others then
                    v_ind_obt_comision := 'N';
              end;

              if nvl(cc.mto_comision, 0) <> 0 and nvl(v_ind_obt_comision, 'N') ='S' then
                 v_cta_com_bancard := fue_obt_val_max_refcodes('NRO_CTA_COM_BANCARD', cc.nro_cta_credito);
                 v_ind_obt_comision := 'S';
                 v_mto_credito := v_mto_credito - nvl(cc.mto_comision,0);
              else
                 v_ind_obt_comision := 'N';
              end if;
              -- si no es una cuenta ficticia
              IF cc.nro_cta_credito <> v_cta_deb_icb then
                pag_cta.PR_VER_OPERACION(cc.nro_cta_credito,v_cod_tra_padre,4,41,'C',
                           cc.cod_moneda,v_mto_credito,v_cod_oficina,
                           v_cod_modulo, v_cod_modalidad, v_nvo_estado,
                           v_sal_disponible,v_procesa,v_cod_tra_credito);
                v_cod_mon_credito := pag_cta.G_CTAS.COD_MONEDA;
              end if;

              if v_procesa = 'N' then
                 v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
              elsif v_cod_mon_credito <> v_cod_mon_debito THEN /*monedas difer,no permitir*/
                 v_cod_tra_debito := NULL;
                 v_msj_error := 'Monedas diferentes';
              end if;


              --Se procesa la comisión a Bancard.

               if nvl(v_ind_obt_comision, 'N') = 'S' then
                  pag_cta.PR_VER_OPERACION(v_cta_com_bancard,v_cod_tra_padre,4,41,'C',
                             cc.cod_moneda,cc.mto_comision,v_cod_oficina,
                             v_cod_mod_com, v_cod_mad_com, v_nvo_est_com,
                             v_sal_dis_com,v_pro_com,v_cod_tra_credito);

                  if v_pro_com = 'N' then
                     v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                  end if;
               end if;
            END IF;
          END IF;
          IF v_msj_error IS NULL AND v_es_ficticia = 'N' and nvl(cc.monto,0) <> 0 THEN -- EC - 12/07/10 : No generar movimientos con monto = 0 - Ap N° 428
            /* se puede realizar transferencia */
            -- calculo el numero de documento -----------------------------
            IF LENGTH(cc.nro_documento) > 7 THEN
              v_nro_documento := SUBSTR(cc.nro_documento,-7,7);
            ELSE
              v_nro_documento := cc.nro_documento;
            END IF;
            v_nro_documento3 := cc.nro_documento;
            -- debito a la cuenta de debito
            v_nro_secuencia := v_nro_secuencia + 1;
            pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_documento3);
            pag_cta.pr_act_operacion(cc.nro_cta_debito,
                                     v_hora,
                                     'D',
                                     cc.cod_moneda,
                                     cc.monto,
                                     v_cod_tra_padre,
                                     v_cod_tra_debito,
                                     v_nro_documento,
                                     null,
                                     v_cod_oficina,
                                     4,
                                     41,
                                     null,
                                     null,
                                     'Infonet Cobranza',
                                     'N',
                                     v_nro_secuencia,
                                     v_fec_actual);
             declare
               v_det_error ge_mov_dat_adicionales_err.det_error%type;
               v_cod_modulo ge_cuentas.cod_modulo%type;
               v_cod_modalidad ge_modalidades.cod_modalidad%type;
               v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
             begin
                begin
                  select cod_modulo, cod_modalidad, cod_sub_modalidad
                    into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad
                    from ge_cuentas
                   where nro_cuenta = cc.nro_cta_debito;
                exception
                  when others then
                     v_cod_sub_modalidad := 25;
                end;
                begin
                  insert into ge_mov_dat_adicionales (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                              cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre,
                                              cod_moneda, monto, cod_extorno, nro_documento,
                                              nro_transaccion, liberado, fec_acreditacion, tip_operacion)
                                       values(v_fec_actual, v_fec_actual, user, v_hora, nvl(v_nro_secuencia, 1), cc.hor_referencia,
                                              v_cod_modulo, v_cod_modalidad, cc.nro_cta_debito, nvl(v_cod_tra_padre,227),
                                              cc.cod_moneda, cc.monto, '00', v_nro_documento,
                                              v_nro_documento3, 'S', v_fec_actual, 'TRA');
                 exception
                   when others then
                     v_det_error := substr(sqlerrm, 1,4000);
                     insert into ge_mov_dat_adicionales_err (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                     cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre,
                                                     cod_moneda, monto, cod_extorno, nro_documento,
                                                     nro_transaccion, liberado, fec_acreditacion, det_error,tip_operacion )
                                              values(v_fec_actual, v_fec_actual, user, v_hora, nvl(v_nro_secuencia, 1), cc.hor_referencia,
                                                     v_cod_modulo, v_cod_modalidad, cc.nro_cta_debito, nvl(v_cod_tra_padre,227),
                                                     cc.cod_moneda, cc.monto, '00', v_nro_documento,
                                                     v_nro_documento3, 'S', v_fec_actual, v_det_error, 'TRA');
	               end;
              end;

            if pag_cta.g_cod_error <> 0 then
               -- actualizacion con problemas
               v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
            else
               -- se hace el credito -- no realiza para la cuenta credito ficticia
               IF cc.nro_cta_credito <> v_cta_deb_icb then
                 v_nro_secuencia := v_nro_secuencia + 1;
                 pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_documento3);
                 pag_cta.pr_act_operacion(cc.nro_cta_credito,
                                           v_hora,
                                           'C',
                                           cc.cod_moneda,
                                           v_mto_credito,
                                           v_cod_tra_padre,
                                           v_cod_tra_credito,
                                           v_nro_documento,
                                           null,
                                           v_cod_oficina,
                                           4,
                                           41,
                                           null,
                                           null,
                                           'Infonet Cobranza',
                                           'N',
                                           v_nro_secuencia,
                                           v_fec_actual);
                 end if;
                 declare
                    v_det_error ge_mov_dat_adicionales_err.det_error%type;
                    v_cod_modulo ge_cuentas.cod_modulo%type;
                    v_cod_modalidad ge_modalidades.cod_modalidad%type;
                    v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
                 begin
                   begin
                     select cod_modulo, cod_modalidad, cod_sub_modalidad
                       into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad
                       from ge_cuentas
                      where nro_cuenta = cc.nro_cta_credito;
                  exception
                    when others then
                       v_cod_sub_modalidad := 25;
                  end;
                  begin
                    insert into ge_mov_dat_adicionales (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre,
                                                cod_moneda, monto, cod_extorno, nro_documento,
                                                nro_transaccion, liberado, fec_acreditacion, tip_operacion)
                                         values(v_fec_actual, v_fec_actual, user, v_hora, nvl(v_nro_secuencia, 1), cc.hor_referencia,
                                                v_cod_modulo, v_cod_modalidad, cc.nro_cta_credito, nvl(v_cod_tra_padre,227),
                                                cc.cod_moneda, v_mto_credito, '00', v_nro_documento,
                                                v_nro_documento3, 'S', v_fec_actual, 'TRA');
                  exception
                    when others then
                      v_det_error := substr(sqlerrm, 1,4000);
                      insert into ge_mov_dat_adicionales_err (fecha, fec_valor, cod_usuario, hora, nro_secuencia, hor_referencia,
                                                      cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre,
                                                      cod_moneda, monto, cod_extorno, nro_documento,
                                                      nro_transaccion, liberado, fec_acreditacion, det_error, tip_operacion )
                                               values(v_fec_actual, v_fec_actual, user, v_hora, nvl(v_nro_secuencia, 1), cc.hor_referencia,
                                                      v_cod_modulo, v_cod_modalidad, cc.nro_cta_credito, nvl(v_cod_tra_padre,227),
                                                      cc.cod_moneda, v_mto_credito, '00', v_nro_documento,
                                                      v_nro_documento3, 'S', v_fec_actual, v_det_error, 'TRA');
	               end;
              end;


                pag_cta.PR_SET_NRO_DOCUMENTO3(null);


                if pag_cta.g_cod_error <> 0 then
                  -- actualizacion con problemas
                  v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                end if;

                if nvl(v_ind_obt_comision, 'N') = 'S' then
                   v_nro_secuencia := v_nro_secuencia + 1;
                   pag_cta.PR_SET_NRO_DOCUMENTO3(v_nro_documento3);
                   pag_cta.pr_act_operacion(v_cta_com_bancard,
                                            v_hora,
                                            'C',
                                            cc.cod_moneda,
                                            cc.mto_comision,
                                            v_cod_tra_padre,
                                            v_cod_tra_credito,
                                            v_nro_documento,
                                            null,
                                            v_cod_oficina,
                                            4,
                                            41,
                                            null,
                                            null,
                                            v_con_mov_com_bancard,
                                            'N',
                                            v_nro_secuencia,
                                            v_fec_actual);
                   pag_cta.PR_SET_NRO_DOCUMENTO3(null);
                if pag_cta.g_cod_error <> 0 then
                  -- actualizacion con problemas
                  v_msj_error     := substr(ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 200);
                end if;
               end if;
             end if;
             if v_msj_error is null then
               -- actualizo el movimiento como procesado
               UPDATE ge_mov_inf_cobranzas
                  SET liberado = 'S'
                WHERE rowid = cc.fila;
             else
               UPDATE ge_mov_inf_cobranzas
                  SET observacion = v_msj_error
               WHERE rowid = cc.fila;
             end if;
          end if;
          if  v_msj_error is not null then
            --- hubo error, grabo el motivo del error -----------------------
            UPDATE ge_mov_inf_cobranzas
               SET observacion = v_msj_error
             WHERE rowid = cc.fila;
          END IF;
          -- fin de un registro de transferencia -----------------------------
        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,'Error al procesar cobranzas: ' || sqlerrm);
      END;
      --

begin
    -- genera el debito contable en el dia de la operacion
    --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
    v_hora := to_char(sysdate,'HH24:MI:SS');
    v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    if nvl(p_tip_proceso, 'C') = 'C' then
       lp_gen_mov_contable;
    end if;
    -- genera el credito y debito a las 48 horas
    --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
    v_hora := to_char(sysdate,'HH24:MI:SS');
    v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    lp_deb_pendientes;
end;
/

