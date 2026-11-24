CREATE OR REPLACE PROCEDURE IT.PRC_PRO_DEB_CHEQUERA
 (P_NRO_CUENTA IN CC_CHEQUERAS.NRO_CUENTA%TYPE
 ,P_NRO_CHE_INI IN CC_CHEQUERAS.NRO_CHE_INICIAL%TYPE
 ,P_NRSECUE IN NUMBER
 )
 IS
V_FILA    VARCHAR2(100);
V_MONTIMP NUMBER(18, 2);
V_VLTASCA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_CDTASCA GE_MOVIMIENTOS.COD_TASA%TYPE;
V_CDMODUL CC_CTA_CORRIENTES.COD_MODULO%TYPE;
V_CDMODAL CC_CTA_CORRIENTES.COD_MODALIDAD%TYPE;
V_CDOFICI CC_CTA_CORRIENTES.COD_OFICINA%TYPE;
V_NRCUENT CC_CTA_CORRIENTES.NRO_CUENTA%TYPE;
V_TPSOLCH CC_CHEQUERAS.TIPO%TYPE;
V_TPCHEQ  CC_SOL_CHEQUERAS.TIP_SOLICITUD%TYPE;
V_CDTASAS GE_MOVIMIENTOS.COD_TASA%TYPE;
V_TPVLPOR GE_TASAS.TIP_VALOR%TYPE;
V_IMTRANS NUMBER(18, 2);
V_VLTASA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_FCDETAS DATE;
V_TPDETAS GE_TASAS.TIPO%TYPE;
V_MONTCAR NUMBER(18, 2);
V_TRA_PRO VARCHAR2(1);
V_CTCHEQU NUMBER(8);
V_NRCHINI CC_CHEQUERAS.NRO_CHE_INICIAL%TYPE;
V_HRMOVIM GE_MOVIMIENTOS.HORA%TYPE;
V_AUXILIAR NUMBER(2);
V_ESCTAOL CC_CTA_CORRIENTES.ESTADO%TYPE;
V_CHQGRAT NUMBER(8);
V_CTCHANT NUMBER(18);
V_CDMONED CC_CTA_CORRIENTES.COD_MONEDA%TYPE;
V_TIENETP CC_CTA_CORRIENTES.TRA_PROHIBIDA%TYPE;
V_TIENEAU CC_CTA_CORRIENTES.AUT_PENDIENTE%TYPE;
V_CDUSUAR GE_MOVIMIENTOS.COD_USUARIO%TYPE;
V_FCDEHOY DATE;
V_SLTOTOL CC_CTA_CORRIENTES.SAL_TOTAL%TYPE;
V_FCULMOV CC_CTA_CORRIENTES.FEC_ULT_MOVIMIENTO%TYPE;
V_HRULMOV CC_CTA_CORRIENTES.HOR_ULT_MOVIMIENTO%TYPE;
V_TASAPER CC_CTA_CORRIENTES.TAS_PERSONALIZADA%TYPE;
V_CDTRANS GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_CONCEPTO VARCHAR2(200);
V_NRSECUE NUMBER(8);
V_MONLOC BA_MONEDAS.COD_MONEDA%TYPE;
V_AUXI NUMBER(8);
v_redondeo number(5);

v_cob_pri_chequera varchar2(1);
v_can_chequeras number(8);
v_cdsubmodal cc_cta_corrientes.cod_sub_modalidad%type;
v_fec_solicitud date;
v_fec_inicio date;
v_cod_paq_exnomina ge_paquetes.cod_paquete%type := fug_obt_pardinamico('COD_PAQ_EXNOMINA');

CURSOR cheques IS
  select distinct gec.cod_modulo,gec.cod_modalidad,gec.cod_sub_modalidad,gec.cod_oficina,cc.nro_cuenta, cc.tipo
    from cc_chequeras cc,
         ge_cuentas  gec
   where cc.estado = 'N'
     and cc.nro_cuenta      = nvl(p_nro_cuenta,cc.nro_cuenta)
     and cc.nro_che_inicial = nvl(p_nro_che_ini,cc.nro_che_inicial)
     and cc.fec_solicitud  <= v_fcdehoy
     and cc.nro_cuenta      = gec.nro_cuenta;
cursor ctacte is
  select cod_moneda,tra_prohibida,aut_pendiente,sal_total,
         fec_ult_movimiento,hor_ult_movimiento,tas_personalizada,estado,
         rowid fila
    from cc_cta_corrientes
   where cod_modulo    = v_cdmodul
     and cod_modalidad = v_cdmodal
     and cod_oficina   = v_cdofici
     and nro_cuenta    = v_nrcuent
  union
  select cod_moneda,'N' tra_prohibida,'N' aut_pendiente,sal_total,
         fec_ult_movimiento,hor_ult_movimiento,'N' tas_personalizada,estado,
         rowid fila
    from cc_cta_bancarias
   where cod_modulo    = v_cdmodul
     and cod_modalidad = v_cdmodal
     and cod_oficina   = v_cdofici
     and nro_cuenta    = v_nrcuent;

BEGIN
    v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
    v_monloc  := pag_gen.fu_obt_mon_local;
    v_hrmovim := TO_CHAR(SYSDATE,'HH24:MI:SS');
    v_cdusuar := substr(user,1,10);
    v_tra_pro := 'N';
    -----CONTROLA QUE TODOS LOS REGISTROS HAYAN SIDO PROCESADOS-----
    select nvl(count(*),0)
      into v_auxi
      from cc_chequeras
     where estado in ('S','E')
       and fec_solicitud   = v_fcdehoy
       and nro_cuenta      = nvl(p_nro_cuenta,nro_cuenta)
       and nro_che_inicial = nvl(p_nro_che_ini,nro_che_inicial);
    If v_auxi > 0 then
      raise_application_error(-20000,'Existen pedidos no enviados...verificar..');
    end if;
    -- ACTUALIZACION DE DATOS
    OPEN cheques;
    LOOP
       FETCH cheques INTO v_cdmodul,v_cdmodal,v_cdsubmodal,v_cdofici,v_nrcuent,v_tpsolch;
       EXIT WHEN cheques%NOTFOUND;
       --- calculo la cantidad total de cheques y el menor numero ----
       select sum(nvl(can_cheques,0)),min(nro_che_inicial)
         into v_ctchequ, v_nrchini
         from cc_chequeras
        where nro_cuenta      = v_nrcuent
          and nro_che_inicial = nvl(p_nro_che_ini,nro_che_inicial)
          and tipo            = v_tpsolch
          and estado          = 'N'
          and fec_solicitud  <= v_fcdehoy;
       ----------------------------------------------------------------
       v_hrmovim := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hrmovim);
       IF ctacte%ISOPEN THEN
          CLOSE ctacte;
       END IF;
       OPEN ctacte;
       FETCH ctacte INTO v_cdmoned,v_tienetp,v_tieneau,v_sltotol,
                         v_fculmov,v_hrulmov,v_tasaper,v_esctaol,
                         v_fila;
       IF ctacte%FOUND and v_esctaol NOT IN ('C','T','D') THEN /* se puede debitar */
           v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cdmodul,v_cdmodal,v_cdmoned);

           -- Hallamos el tipo de chequera de la solicitud (M:mostrador - C:casa) - RABP-PCC-29/01/2013
            select NVL(s.tip_solicitud,'M') tip_solicitud
              into V_TPCHEQ
              from cc_chequeras c, cc_sol_chequeras s
             where c.nro_cuenta      = s.nro_cuenta
               and c.fec_solicitud   = s.fecha
               and c.hor_solicitud   = s.hora
               and c.nro_cuenta      = v_nrcuent
               and c.nro_che_inicial = nvl(p_nro_che_ini,nro_che_inicial)
               and tipo              = v_tpsolch
               and c.estado          = 'N'
               and fec_solicitud     <= v_fcdehoy;

           -- Cambiamos de estado la chequera
           update cc_chequeras
                set estado = 'I'
            where nro_cuenta      = v_nrcuent
              and tipo            = v_tpsolch
              and estado          = 'N'
              and nro_che_inicial = nvl(p_nro_che_ini,nro_che_inicial)
              and fec_solicitud  <= v_fcdehoy;
           IF v_ctchequ > 0 THEN /* solo si hay cheques a cobrar */
             If v_tienetp = 'S' then
               v_tra_pro := PAG_CTA.FU_VER_TRA_PROHIBIDA (v_nrcuent,540,v_cdmodul,v_cdmodal);
             End if;

             --Ver si no tiene exonerado el cobro de la primera Chequera
             begin
                v_cob_pri_chequera := 'S';
                select count(1)
                  into v_can_chequeras
                  from cc_chequeras
                 where estado = 'E'
                   and nro_cuenta = v_nrcuent;
             end;

             /*
             || Exonerar del cargo a las cuentas existentes
             || que pasan a pertenecer a un paquete de Segmento Preferetne
             || y ya se le cobró anteriormente la primera chequera.
             */
             begin
                select c.fec_inicio
                into   v_fec_inicio
                from   ge_paq_cuentas p, ge_paq_clientes c, ge_paquetes g
                where  p.cod_paquete = g.cod_paquete
                and    p.cod_paquete = c.cod_paquete
                and    p.cod_persona = c.cod_persona
                and    p.nro_secuencia = c.nro_secuencia
                and    p.cod_paquete <> v_cod_paq_exnomina --PCCDEEVO-601 Paquete de Clientes EX-NOMINA
                --and    g.cod_seg_preferente is not null--dydmr2487 fm 07/10/2015                
                and    c.estado = 'N'
                and    p.nro_cuenta = v_nrcuent;
             exception
                when no_data_found then
                   v_fec_inicio := null;
                when others then
                   raise_application_error(-20000,'Error Obt.Paquete Seg.Preferente: '||v_nrcuent);
             end;

             if v_fec_inicio is not null then
                select count(1)
                  into v_can_chequeras
                  from cc_chequeras
                 where estado = 'E'
                   and nro_cuenta = v_nrcuent
                   and fec_solicitud > v_fec_inicio; -- para que no se le cobre el cargo
             end if;
             -- fin modificacion Paquete Premium - Por RABF-11/may/2011

             if nvl(v_can_chequeras,0) = 0  then
               v_cob_pri_chequera := fug_obt_pardinamico('COB_PRI_CHEQUERA',v_cdmodul,v_cdmodal,v_cdmoned,null,v_cdsubmodal);
             end if;

             --If v_tra_pro = 'N' and v_cdmodal = 41 and nvl(v_cob_pri_chequera,'S') = 'S' then  -- solo se cobra si es cuenta corriente de clientes
             /*
             || PCC-Exoneración y Extorno de Comisiones y Tasas
             || Se comenta para que realice el cálculo siempre
             */

                 if V_TPCHEQ = 'C' then  -- Chequera en Casa
                   select cod_tas_casa
                     into v_cdtasas
                     from cc_tip_chequeras
                    where cod_tip_chequera = v_tpsolch;
                 else -- Chequera Mostrador
                   select cod_tasa
                     into v_cdtasas
                     from cc_tip_chequeras
                    where cod_tip_chequera = v_tpsolch;
                 end if;

                 If v_cdtasas is null then
                    raise_application_error(-20000,'Tasa no defenida para el tipo de chequera: '||v_tpsolch );
                 End if;
                 v_tpvlpor := null;
                 v_imtrans := 0;
                 v_vltasa  := 0;
                 v_fcdetas := null;
                 v_tpdetas := null;
                 PAG_GEN.PR_OBT_VAL_TASA (v_cdmodul
                                         ,v_cdmodal
                                         ,v_cdofici
                                         ,v_nrcuent
                                         ,v_cdmoned
                                         ,null  --importe
                                         ,nvl(v_tasaper,'N')
                                         ,v_cdtasas
                                         ,null -- transaccion
                                         ,v_fcdehoy
                                         ,v_vltasa
                                         ,v_fcdetas
                                         ,v_tpvlpor
                                         ,v_tpdetas);
                 v_montcar := 0;
                 IF v_tpvlpor <> 'V' THEN
                    raise_application_error(-20000,'Cargo debe ser valor');
                 else
                   v_montcar := NVL(to_number(v_vltasa),0) *  v_ctchequ;
                   IF NVL(to_number(v_cdtasas),0) <> 0 AND
                      NVL(to_number(v_vltasa),0) <> 0 THEN
                     --v_nrsecue := v_nrsecue + 1;
                     v_concepto:= 'Cheques - No ';
                     v_concepto:= v_concepto||TO_CHAR(v_nrchini)||' a ';
                     v_concepto:= v_concepto||TO_CHAR(v_nrchini+v_ctchequ-1);
                     v_concepto:= SUBSTR(v_concepto,1,35);
                     v_montcar := ROUND(to_number(v_montcar),v_redondeo);
                     ---
                     If v_tra_pro = 'N' and v_cdmodal = 41 and
                        nvl(v_cob_pri_chequera,'S') = 'S' then
                        -- solo se cobra si es cuenta corriente de clientes
                        insert into ge_movimientos
                          (cod_usuario,hora,nro_secuencia,
                           cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
                           cod_moneda,cod_tra_padre,cod_transaccion,fecha,
                           fec_valor,monto,estado,emi_aviso,
                           cod_ofi_origen,cod_tasa,val_tasa,concepto,
                           cod_mod_padre,cod_mad_padre,reversado,protegido)
                        values
                           (v_cdusuar,v_hrmovim,p_nrsecue,
                            v_cdmodul,v_cdmodal,v_cdofici,v_nrcuent,v_cdmoned,
                            540,540,v_fcdehoy,v_fcdehoy,
                            v_montcar,'N','N',v_cdofici,
                            v_cdtasas,v_vltasa,v_concepto,
                            v_cdmodul,v_cdmodal,'N','N');
                     ELSE
                        prg_ins_exoneracion(540,v_cdmodul,v_cdmodal,v_cdmoned,
                                            v_nrcuent,null,v_cdtasas,
                                            v_montcar,v_vltasa,null,v_montcar);
                     END IF;
                     --
                     v_cdtasca := v_cdtasas;
                     v_vltasca := v_vltasa;
                     v_imtrans := v_montcar;
                     v_cdtrans := 541;
                     v_tasaper := v_tasaper;
                     v_cdtasas := null;
                     v_tpvlpor := null;
                     v_vltasa  := 0;
                     v_fcdetas := null;
                     v_tpdetas := null;
                     SELECT descripcion
                        INTO v_concepto
                       FROM ge_transacciones
                      WHERE cod_modulo = 4  AND
                            cod_modalidad = v_cdmodal AND
                            cod_transaccion = v_cdtrans;
                     PAG_GEN.PR_OBT_VAL_TASA(v_cdmodul,
                                         v_cdmodal,
                                         v_cdofici,
                                         v_nrcuent,
                                         v_cdmoned,
                                         v_imtrans, -- importe
                                         nvl(v_tasaper,'N'),
                                         v_cdtasas, -- tasa
                                         v_cdtrans, -- Transaccion
                                         v_fcdehoy,
                                         v_vltasa,
                                         v_fcdetas,
                                         v_tpvlpor,
                                         v_tpdetas);
                     v_montimp := 0;
                     If nvl(to_number(v_cdtasas),0) <> 0  and
                        nvl(to_number(v_vltasa),0) <> 0  then
                        if v_tpvlpor = 'V' then
                          v_montimp := v_vltasa;
                        else
                          v_montimp := to_number(v_imtrans)* to_number(v_vltasa)/100;
                          --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                          v_montimp := pag_gen.FU_OBT_VAL_FINAL(v_montimp);
                        end if;

                        v_montimp := round(to_number(v_montimp),v_redondeo);
                        v_nrsecue := p_nrsecue + 1;
                        --
                        If v_tra_pro = 'N' and v_cdmodal = 41 and
                           nvl(v_cob_pri_chequera,'S') = 'S' then
                           -- solo se cobra si es cuenta corriente de clientes
                           insert into ge_movimientos
                            (cod_usuario,hora,nro_secuencia,
                             cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,
                             cod_moneda,cod_tra_padre,cod_transaccion,fecha,
                             fec_valor,monto,estado,emi_aviso,
                             cod_ofi_origen,cod_tasa,val_tasa,cod_mod_padre,
                             cod_mad_padre,reversado,protegido,concepto)
                           values
                           (v_cdusuar,v_hrmovim,v_nrsecue,
                             v_cdmodul,v_cdmodal,v_cdofici,v_nrcuent,v_cdmoned,
                             540,541,v_fcdehoy,v_fcdehoy,
                             v_montimp,'N','N',v_cdofici,
                             v_cdtasas,v_vltasa,v_cdmodul,
                             v_cdmodal,'N','N',v_concepto);
                        ELSE
                           prg_ins_exoneracion(541,v_cdmodul,v_cdmodal,v_cdmoned,
                                               v_nrcuent,null,v_cdtasas,
                                               v_montcar,v_vltasa,null,v_montcar);
                        END IF;
                        --
                        -- FB 15.06.2010 finalizo aqui el bloque, anteriormente cuando el cliente tenía tasa personalizada ya no ingresaba y saltaba la catualizacion del saldo total
                     end if;
                     If v_tra_pro = 'N' and v_cdmodal = 41 and
                        nvl(v_cob_pri_chequera,'S') = 'S' then
                        -- solo se cobra si es cuenta corriente de clientes
                        IF v_esctaol IN ('A','I') THEN
                          PAG_CTA.PR_ACT_ESTADO(v_nrcuent,'N',v_fcdehoy,v_hrmovim,null);
                          if v_cdmodal = 41 then
                            update cc_cta_corrientes set
                                 fec_ult_movimiento = v_fcdehoy,
                                 hor_ult_movimiento = v_hrmovim,
                                 sal_total = nvl(sal_total,0)-
                                             nvl(to_number(v_montcar),0)-
                                             nvl(to_number(v_montimp),0)
                            WHERE rowid = v_fila;
                          else
                            update cc_cta_bancarias set
                                 fec_ult_movimiento = v_fcdehoy,
                                 hor_ult_movimiento = v_hrmovim,
                                 sal_total = nvl(sal_total,0)-
                                             nvl(to_number(v_montcar),0)-
                                             nvl(to_number(v_montimp),0)
                            WHERE rowid = v_fila;
                          end if;
                        else
                          if v_cdmodal = 41 then
                              update cc_cta_corrientes set
                                   fec_ult_movimiento = v_fcdehoy,
                                   hor_ult_movimiento = v_hrmovim,
                                   estado    = v_esctaol,
                                   sal_total = nvl(sal_total,0)-
                                               nvl(to_number(v_montcar),0)-
                                               nvl(to_number(v_montimp),0)
                            WHERE rowid = v_fila;
                          else
                              update cc_cta_bancarias set
                                   fec_ult_movimiento = v_fcdehoy,
                                   hor_ult_movimiento = v_hrmovim,
                                   estado    = v_esctaol,
                                   sal_total = nvl(sal_total,0)-
                                               nvl(to_number(v_montcar),0)-
                                               nvl(to_number(v_montimp),0)
                            WHERE rowid = v_fila;
                          end if;
                        End if;
                        --FB: 15.06.2010  END IF; Todo esto se saltaba al tener exonerada la tasa.
                     END IF;
                   END IF;
                 END IF;
             --END IF;
           END IF;
      ELSE  /* estado de cta incorrecta, no se pudo debitar*/
         UPDATE cc_chequeras
            SET estado = 'I'
          WHERE nro_cuenta = v_nrcuent
            AND tipo = v_tpsolch
            AND nro_che_inicial = nvl(p_nro_che_ini,nro_che_inicial)
            AND estado = 'N'
            AND fec_solicitud <= v_fcdehoy;
      END IF;
      IF ctacte%ISOPEN THEN
        CLOSE ctacte;
      END IF;
    END LOOP;
    IF cheques%ROWCOUNT = 0 THEN
       raise_application_error(-20000,'No existen Chequeras a imprimir');
    END IF;
    CLOSE cheques;
exception
    when others then
      raise_application_error(-20000,sqlerrm);
END;
/

