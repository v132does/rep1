CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_TRANSFERENCIAS
is
/* Proceso diario que genera los movimientos de:
   1. Alta de Transferencias Recibidas - CR/DB Ctas de Orden,
   2. Devolución o Anulación de Transferencias recibidas.
   2.1 Dar de baja en ctas de orden si la fecha actual todavia no alcanzo la fecha valor
   2.2 Dar de baja Libranzas a Pagar si la fecha actual es igual o mayor a la fecha valor
   3. Debito Cta. Corresponsal,
   3.1 Credito a Libranzas a Pagar
   3.2 DB/CR Cta de Orden
   4. Credito Cta Corresponsal de Transferencias Enviadas en el Día*/
   
--Creado para Exclusion de Transferencias anuladas o devueltas con Error - DYDMR-11519 / 04-09-2019 --
--Variable--
  v_val_parametro ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('NRO_REF_EXCLUIR');
  
-- Transferencias Recibidas registradas en el dia
cursor c_trans_rec is
  select t.*, substr('//'||nro_ref_externa||'//'||nom_beneficiario,1,100) concepto, t.rowid 
    from lc_transferencias t
   where nvl(t.procesado, 'N') = 'N'
     and t.estado <> 'B'
     and t.cod_modalidad = 75;
-- Transferencias Recibidas anuladas o devueltas en el dia
cursor c_trans_rec_anu is
  select t.*, substr('//'||nro_ref_externa||'//'||nom_beneficiario,1,100) concepto
    from lc_transferencias t
   where t.fec_cam_estado = pag_cal.fu_obt_fec_actual(7)
     and t.cod_modalidad = 75
     and t.estado in ('AN', 'DE')
     and INSTR(NVL(V_VAL_PARAMETRO, '0'), t.nro_referencia) = 0;--DYDMR-11519 / 04-09-2019
-- Cobertura o Fondeo de Transferencias cuando fec_valor = fecha calendario
cursor c_trans_fon is
  select t.*, b.nro_cuenta, b.cod_oficina cod_ofi_cta_corresponsal,
         substr('//'||t.nro_ref_externa||'//'||t.nom_beneficiario,1,100) concepto
    from lc_transferencias t, cc_cta_bancarias b
   where t.cod_bco_corresponsal = b.cod_banco
     and t.cod_modalidad = 75
     and b.cod_modalidad = 45
     and b.estado = 'N'
     and t.cod_moneda = b.cod_moneda
     and t.fec_valor between  (pag_cal.fu_obt_fec_actual(7) - 60) and pag_cal.fu_obt_fec_actual(7) -- Se considerara las transferencias vencidas durante los ultimos 60 dias hasta la fecha
     and t.fec_operacion >= (pag_cal.fu_obt_fec_actual(7) - 60)
     and t.estado not in ('AN','DE')
     and not exists (select 1
                       from cc_movimientos_his h
                      where h.cod_tra_padre = 1254
                        and h.cod_transaccion = 1503
                        and h.concepto  like '//'||t.nro_ref_externa||'//%'
                        and h.reversado ='N'
                        and h.nro_documento = T.NRO_REFERENCIA
                        and h.fecha >= (pag_cal.fu_obt_fec_actual(7) - 60));

-- Transferencias Enviadas en el dia
cursor c_trans_env is
  select t.*, b.nro_cuenta, t.cod_oficina cod_ofi_transferencia,
         substr('//'||t.nro_ref_externa||'//'||t.nom_beneficiario,1,100) concepto, t.rowid
    from lc_transferencias t, cc_cta_bancarias b
   where t.cod_bco_corresponsal = b.cod_banco
     and t.cod_modalidad = 72
     and b.cod_modalidad = 45
     and t.estado = 'E'
     and b.estado = 'N'
     and t.cod_moneda = b.cod_moneda
     and t.fec_cam_estado = pag_cal.fu_obt_fec_actual(7)
     and t.procesado = 'N'
     --para no generar el credito a las transferencias emitidas generadas por el proceso de compensacion de cheques
     and t.cod_msj_swift <> 202;

  r_gmovi          ge_movimientos%Rowtype;
  v_hora           ge_movimientos.hora%Type;
  v_fecha          ge_movimientos.fecha%Type;
  v_nro_secuencia  ge_movimientos.nro_secuencia%Type := -999;
  v_nro_cuenta     ge_movimientos.nro_cuenta%Type;
  v_ofi_cuenta     ge_movimientos.cod_ofi_origen%Type;

begin

  v_hora       := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_fecha      := pag_cal.fu_obt_fec_actual(7);
  for rg_tra in c_trans_rec loop
      -- Generar movimientos en Cuenta de Orden
       v_nro_secuencia        := nvl(v_nro_secuencia,0) + 1;
       r_gmovi.nro_secuencia  := v_nro_secuencia;
       r_gmovi.cod_usuario    := User;
       r_gmovi.hora           := v_hora;
       r_gmovi.fecha          := v_fecha;
       r_gmovi.cod_modulo     := 7;
       r_gmovi.cod_modalidad  := 75;
       -- 23.10.2009 Modificado para centralizar el movimiento en la oficina 31
       r_gmovi.cod_oficina    := 31; --rg_tra.cod_oficina;
       r_gmovi.nro_cuenta     := Null;
       r_gmovi.cod_moneda     := rg_tra.cod_moneda;
       r_gmovi.monto          := rg_tra.monto;
       r_gmovi.est_cuenta     := null;
       r_gmovi.cod_tra_padre  := 1254;
       r_gmovi.cod_mod_padre  := 7;
       r_gmovi.cod_mad_padre  := 75;
       r_gmovi.fec_valor      := rg_tra.fec_operacion;
       r_gmovi.reversado      := 'N';
       r_gmovi.protegido      := 'N';
       r_gmovi.estado         := 'N';
       r_gmovi.cod_ofi_origen := rg_tra.cod_oficina;
       r_gmovi.nro_documento  := rg_tra.nro_referencia;
       r_gmovi.cod_tip_ope_cambio := rg_tra.cod_tip_referencia;
       r_gmovi.nro_documento3 := null;
       r_gmovi.concepto       := rg_tra.concepto;
       r_gmovi.emi_aviso       := 'N';
       r_gmovi.cod_transaccion := 1254;
       pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
       UPDATE LC_TRANSFERENCIAS 
          SET PROCESADO = 'S'
          WHERE ROWID = RG_TRA.ROWID;
  end loop;
  v_hora       := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  for rg_tra in c_trans_rec_anu loop
    -- OMM 05/09/2011 Se agrego para generar la reversion de Libranza
    if rg_tra.fec_operacion <> pag_cal.fu_obt_fec_actual(7) and 
       rg_tra.fec_valor < pag_cal.fu_obt_fec_actual(7) then
       -- Generar Credito Cta. Corresponsal...
        v_nro_cuenta := null;
        v_ofi_cuenta := null ;
       Begin
          select c.nro_cuenta, c.cod_oficina 
            into v_nro_cuenta, v_ofi_cuenta
          from cc_cta_bancarias c
         where c.cod_banco = rg_tra.cod_bco_corresponsal 
           and c.cod_modalidad = 45
           and c.estado = 'N'
           and c.cod_moneda = rg_tra.cod_moneda;
        exception
           when others then
                raise_application_error(-20000, 'Error al Buscar Cta. Bancaria'||chr(13)||
                                                'Cargar la Referencia Nro: '||rg_tra.nro_referencia||' en el par_dinamico "NUMERO DE REFERENCIA A EXCLUIR"'||
                                                chr(13)||sqlerrm);
        end;
        
         v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
         pag_cta.pr_act_operacion(v_nro_cuenta,
                                   v_hora,
                                   'C',
                                   rg_tra.cod_moneda,
                                   rg_tra.monto,
                                   1254,
                                   1501,
                                   rg_tra.nro_referencia,
                                   null,
                                   v_ofi_cuenta,
                                   7,
                                   75,
                                   null,
                                   null,
                                   rg_tra.concepto,
                                   null,
                                   v_nro_secuencia,
                                   v_fecha,
                                   null,
                                   null,
                                   null);
          if pag_cta.fu_obt_cod_error() <> 0 then
             raise_application_error(-20000,'Crédito - Fondeo. '||pag_cta.fu_obt_msj_error());
          end if;
     else
        -- Generar movimientos en Cuenta de Orden
         v_nro_secuencia        := nvl(v_nro_secuencia,0) + 1;
         r_gmovi.nro_secuencia  := v_nro_secuencia;
         r_gmovi.cod_usuario    := User;
         r_gmovi.hora           := v_hora;
         r_gmovi.fecha          := v_fecha;
         -- 23.10.2009 Modificado para centralizar el movimiento en la oficina 31
         r_gmovi.cod_oficina    := 31; --rg_tra.cod_oficina;
         r_gmovi.nro_cuenta     := Null;
         r_gmovi.cod_moneda     := rg_tra.cod_moneda;
         r_gmovi.monto          := (rg_tra.monto * -1);
         r_gmovi.est_cuenta     := null;
         r_gmovi.cod_tra_padre  := 1254;
         r_gmovi.cod_mod_padre  := 7;
         r_gmovi.cod_mad_padre  := 75;
         r_gmovi.fec_valor      := rg_tra.fec_operacion;
         r_gmovi.reversado      := 'N';
         r_gmovi.protegido      := 'N';
         r_gmovi.estado         := 'N';
         r_gmovi.cod_ofi_origen := rg_tra.cod_oficina;
         r_gmovi.nro_documento  := rg_tra.nro_referencia;
         r_gmovi.cod_tip_ope_cambio := rg_tra.cod_tip_referencia;
         r_gmovi.nro_documento3 := null;
         r_gmovi.concepto       := rg_tra.concepto;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.cod_transaccion := 1254;
         r_gmovi.cod_modulo     := 7;
         r_gmovi.cod_modalidad  := 75;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
    end if ;
  end loop;
  -- Generar Debito Cta. Corresponsal...
  v_hora       := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  --v_nro_secuencia := -999;
  for rg_tra in c_trans_fon loop
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
      pag_cta.pr_act_operacion(rg_tra.nro_cuenta,
                               v_hora,
                               'D',
                               rg_tra.cod_moneda,
                               rg_tra.monto,
                               1254,
                               1503,
                               rg_tra.nro_referencia,
                               null,
                               rg_tra.cod_ofi_cta_corresponsal,
                               7,
                               75,
                               null,
                               null,
                               rg_tra.concepto,
                               null,
                               v_nro_secuencia,
                               v_fecha,
                               null,
                               null,
                               null);
      if pag_cta.fu_obt_cod_error() <> 0 then
         raise_application_error(-20000,'Débito - Fondeo. '||pag_cta.fu_obt_msj_error());
      end if;
  end loop;
  -- Generar Crédito Cta. Corresponsal...
  v_hora       := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  --v_nro_secuencia := -999;
  for rg_tra in c_trans_env loop
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
      pag_cta.pr_act_operacion(rg_tra.nro_cuenta,
                               v_hora,
                               'C',
                               rg_tra.cod_moneda,
                               rg_tra.monto,
                               1602,
                               1602,
                               rg_tra.nro_referencia,
                               null,
                               rg_tra.cod_ofi_transferencia,
                               7,
                               72,
                               null,
                               null,
                               rg_tra.concepto,
                               null,
                               v_nro_secuencia,
                               v_fecha,
                               null,
                               null,
                               null);
      if pag_cta.fu_obt_cod_error() <> 0 then
        raise_application_error(-20000,'Crédito Cta.Corresponsal. '||pag_cta.fu_obt_msj_error());
      else
        UPDATE LC_TRANSFERENCIAS 
          SET PROCESADO = 'S'
          WHERE ROWID = RG_TRA.ROWID;
      end if;
  end loop;

exception
  when others then
       raise_application_error(-20000, sqlerrm);
end prg_gen_mov_transferencias;
/

