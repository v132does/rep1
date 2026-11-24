CREATE OR REPLACE PROCEDURE IT.PRG_GEN_TELEGRAMAS
 IS
V_FCDEHOY DATE;
-- 101	SALDO CERO Y SIN MOV. POR 90 DIAS
------------------------------------------
  cursor saldo_101 is
    select cc.nro_cuenta,cl.cod_persona,cc.sal_total saldo,cc.cod_moneda
      from cc_cta_corrientes cc,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       and (cl.relacion = 'P' or  --principal
           (cl.relacion != 'P'    --todos si el principal no es jurídico
             and exists (Select '1'
                           from ba_personas pe, ge_cta_clientes cg
                          where cg.nro_cuenta = cc.nro_cuenta
                            and cg.relacion = 'P'
                            and pe.cod_persona = cg.cod_persona
                            and pe.tipo = 'F')))
       and nvl(cc.sal_total,0) = 0
       and nvl(cc.sal_bloqueado,0) = 0
       and nvl(cc.sal_retenido,0)= 0
       and (trunc(v_fcdehoy) - trunc(cc.fec_ult_movimiento)) between 90 and 94
       and cc.estado = 'I'
       and not exists (select ref_cuentas    --q no tenga teleg x la persona
                         from ge_telegramas
                        where ref_cuentas = cc.nro_cuenta
                          and cod_persona = cl.cod_persona
                          and fec_entrega is null
                          and cod_causa = 101 );
-- 116	SOBREGIRO DESDE 30 DIAS
------------------------------------------
  cursor sobregiro_116 is
    select cc.nro_cuenta,cl.cod_persona,nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) saldo,cc.cod_moneda
      from cc_cta_corrientes cc,
           ge_cta_clientes cl,
           cc_sobregiros_res sob
     where cc.nro_cuenta = cl.nro_cuenta
       and (cl.relacion = 'P' or  --principal
           (cl.relacion != 'P'    --todos si el principal no es jurídico
             and exists (Select '1'
                           from ba_personas pe, ge_cta_clientes cg
                          where cg.nro_cuenta = cc.nro_cuenta
                            and cg.relacion = 'P'
                            and pe.cod_persona = cg.cod_persona
                            and pe.tipo = 'F')))
       and cc.estado not in ('X','A','C','P')
       and cc.nro_cuenta = sob.nro_cuenta
       and sob.can_dias >= 30
       and not exists (select ref_cuentas    --q no tenga teleg x la persona
                         from ge_telegramas
                        where ref_cuentas =cc.nro_cuenta
                          and cod_persona = cl.cod_persona
                          and fec_entrega is null
                          and cod_causa = 116 );
-- 112	CTA.CANCELADA-SAL.>=0. LEY 2835/05  X CAUSAL (se debe param. en el causal d cancelación junto cn la 110)
-- 113	CTA.CANCELADA-SAL.>=0. ART.1425 (se debe param. en el causal d cancelación junto cn la 113)
------------------------------------------
  cursor cancelacion_112_113 is
    select cc.nro_cuenta,cl.cod_persona,
           decode(instr(fug_obt_parcausales(cc.cod_cau_cancelacion,'TIP_TELEGRAMA'),'112'),0,113,112) causa,
           nvl(cc.sal_total,0) - nvl(sal_retenido,0) saldo,cc.cod_moneda
      from cc_cta_corrientes cc,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       and (cl.relacion = 'P' or  --principal
           (cl.relacion != 'P'    --todos si el principal no es jurídico
             and exists (Select '1'
                           from ba_personas pe, ge_cta_clientes cg
                          where cg.nro_cuenta = cc.nro_cuenta
                            and cg.relacion = 'P'
                            and pe.cod_persona = cg.cod_persona
                            and pe.tipo = 'F')))
       and cc.estado  in ('P','C') --cancelada
       and nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) >= 0 --
       and trunc(cc.fec_cam_estado) = trunc(v_fcdehoy)
       and (instr(fug_obt_parcausales(cc.cod_cau_cancelacion,'TIP_TELEGRAMA'),'112')>0 or
            instr(fug_obt_parcausales(cc.cod_cau_cancelacion,'TIP_TELEGRAMA'),'113')>0)
       and not exists (select ref_cuentas    --q no tenga teleg x la persona
                         from ge_telegramas
                        where ref_cuentas =cc.nro_cuenta
                          and cod_persona = cl.cod_persona
                          and fec_entrega is null
                          and cod_causa in (112,113));
-- 110	CTA.CANCELADA-S.DEUDOR LEY2835/05   X CAUSAL
-- 111	CTA.CANCELADA-SAL.DEUDOR ART.1425
------------------------------------------
  cursor cancelacion_deudor_110_111 is
    select cc.nro_cuenta,cl.cod_persona,
           decode(instr(fug_obt_parcausales(cc.cod_cau_cancelacion,'TIP_TELEGRAMA'),'110'),0,111,110) causa,
           nvl(cc.sal_total,0) - nvl(sal_retenido,0) saldo,cc.cod_moneda
      from cc_cta_corrientes cc,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       and (cl.relacion = 'P' or  --principal
           (cl.relacion != 'P'    --todos si el principal no es jurídico
             and exists (Select '1'
                           from ba_personas pe, ge_cta_clientes cg
                          where cg.nro_cuenta = cc.nro_cuenta
                            and cg.relacion = 'P'
                            and pe.cod_persona = cg.cod_persona
                            and pe.tipo = 'F')))
       and cc.estado = 'P' --cerrada, pero con saldo deudor
       and nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) < 0 --deudor
       and trunc(cc.fec_cam_estado) = trunc(v_fcdehoy)
       and (instr(fug_obt_parcausales(cc.cod_cau_cancelacion,'TIP_TELEGRAMA'),'110')>0 or
            instr(fug_obt_parcausales(cc.cod_cau_cancelacion,'TIP_TELEGRAMA'),'111')>0)
       and not exists (select ref_cuentas
                         from ge_telegramas
                        where ref_cuentas = cc.nro_cuenta
                          and cod_persona = cl.cod_persona
                          and fec_entrega is null
                          and cod_causa in (110,111));

--Insertar el telegrama
procedure lp_ins_telegrama
(p_ref_cuentas     in ge_telegramas.ref_cuentas%type
,p_cod_causa      in ge_telegramas.cod_causa%type
,p_fec_generacion in ge_telegramas.fec_generacion%type
,p_cod_persona    in ge_telegramas.cod_persona%type
,p_estado         in ge_telegramas.estado%type
,p_saldo          in ge_telegramas.saldo%type
,p_cod_moneda     in ge_telegramas.cod_moneda%type
,p_monto          in ge_telegramas.monto%type
)
is
begin
   insert into ge_telegramas(cod_telegrama,ref_cuentas,cod_causa,fec_generacion,
                             cod_persona,estado,saldo,cod_moneda,monto)
         values(s_cod_telegrama.nextval,p_ref_cuentas,p_cod_causa,
                p_fec_generacion,p_cod_persona,p_estado,p_saldo,p_cod_moneda,p_monto);
end;
--genera telegrama 104
--DEV.CHEQ X INSUF.FONDOS-DEB.MULTA
procedure lp_gen_telegrama_104 is
  cursor insuf_sobregiro is --falta saldo y multa
    select cc.cod_moneda cod_moneda, cl.cod_persona cod_persona, cc.nro_cuenta nro_cuenta,
           de.nro_cheque nro_cheque, de.fecha fec_devolucion, de.hora hor_devolucion,
           de.sal_multa sal_multa, nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) saldo
      from cc_cta_corrientes cc,
           cc_che_devueltos de,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       --and cl.relacion = 'P'          --cualquier firmante
       and cc.estado not in ('X','A','C','P')
       and de.nro_cuenta = cc.nro_cuenta
       and tipo = 'I'
       and de.fecha = v_fcdehoy
       --and de.sal_multa < de.multa  --se debitó algo de la multa
       and nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0) > 0 --con saldo
       and exists (select 0
                     from cc_che_dev_firmantes c
                    where c.nro_cuenta = de.nro_cuenta
                      and c.nro_cheque = de.nro_cheque
                      and c.cod_persona = cl.cod_persona)
       and exists (select 0
                     from cc_che_dev_totales d, cc_che_dev_firmantes f
                    where d.cod_persona = f.cod_persona
                      and d.tipo = 'I'
                      and d.cantidad between 1 and 4
                      and f.nro_cuenta = de.nro_cuenta
                      and f.nro_cheque = de.nro_cheque
                      and de.fec_insercion >= nvl(d.fec_ult_regularizacion,sysdate-9999))
       /*and exists (Select nvl(cantidad,0) --alguno de los firmantes
                     from cc_che_dev_totales x, cc_che_dev_firmantes z, ge_cta_clientes y
                    where de.nro_cuenta = z.nro_cuenta
                      and de.nro_cheque = z.nro_cheque
                      and x.cod_persona = z.cod_persona
                      and y.cod_persona = z.cod_persona
                      and y.nro_cuenta  = z.nro_cuenta
                      and x.tipo = 'I'
                      and cantidad < 10 \*fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA')*\)*/
--       and cc.nro_cuenta not in (select ref_cuentas
/*         and  not exists  (select 0
                             from ge_telegramas
                            where cod_persona = cl.cod_persona
                              and fec_entrega is null
                              and cod_causa in (104) )*/
  order by cc.cod_moneda, cl.cod_persona, cc.nro_cuenta, de.nro_cheque;
  v_cod_causa number(3) := 104;
  v_cod_moneda varchar2(4) :=  'x';
  v_cod_persona varchar2(10) := '-1';
  v_ref_cuentas varchar2(1000) := null;
  v_cod_telegrama number;
  v_nro_cuenta   varchar2(20);
  v_generar varchar2(1) := 'S';
  v_saldo ge_telegramas.saldo%type :=0;
begin
   for de in insuf_sobregiro loop
      --verificar q la cuenta no tenga transacción prohibida
      If pag_cta.fu_ver_tra_prohibida(de.nro_cuenta,1000,4,41) = 'N' then
         if v_cod_moneda <> de.cod_moneda then
            if v_cod_moneda <> 'x' then
               -- corte por moneda
               select s_cod_telegrama.nextval into v_cod_telegrama from dual;
               insert into ge_telegramas
                  ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
               values
                  (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
               -- actualizo los detalles ya generados
               update ge_telegramas_det
                 set cod_telegrama = v_cod_telegrama
               where cod_telegrama = -1;
            end if;
            v_cod_moneda := de.cod_moneda;
            v_ref_cuentas := null;
            v_cod_persona := de.cod_persona;
            v_nro_cuenta := null;
            -- cerar saldo de la cuenta
            v_saldo := 0;
         end if;
         if v_cod_persona <> de.cod_persona then
             -- corte por persona
             select s_cod_telegrama.nextval into v_cod_telegrama from dual;
             insert into ge_telegramas
                 ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
             values
                 (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
             -- actualizo los detalles ya generados
             update ge_telegramas_det
                set cod_telegrama = v_cod_telegrama
              where cod_telegrama = -1;
             v_ref_cuentas := null;
             v_cod_persona := de.cod_persona;
             v_nro_cuenta := null;
             -- cerar saldo de la cuenta
             v_saldo := 0;
         end if;
         -- concateno las cuentas
         if nvl(v_nro_cuenta,'x') <> de.nro_cuenta then
            select decode(v_ref_cuentas,null,null,v_ref_cuentas||',') || de.nro_cuenta
              into v_ref_cuentas
              from dual;
            --sumar saldo de la cuenta
         end if;
         -- inserto detalles
         insert into ge_telegramas_det
             (cod_telegrama, nro_cuenta, nro_cheque, fecha, hora)
         values
             (-1, de.nro_cuenta, de.nro_cheque, de.fec_devolucion, de.hor_devolucion);
          v_nro_cuenta := de.nro_cuenta;
      else
         v_generar := 'N';--no generar x transacción prohibida
      end if;
   end loop;
   -- ultimo corte
   if v_generar <> 'N' then
      if v_cod_moneda <> 'x' then
         -- corte por moneda
         select s_cod_telegrama.nextval into v_cod_telegrama from dual;
         insert into ge_telegramas
            ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
         values
            (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
         -- actualizo los detalles ya generados
         update ge_telegramas_det
           set cod_telegrama = v_cod_telegrama
         where cod_telegrama = -1;
      end if;
   end if;
end;
--genera telegrama 105
--DEV.CHEQ X INSUF.FOND.-INTIM.MULTA
procedure lp_gen_telegrama_105 is
  cursor insuf_sobregiro is --falta saldo y multa
    select cc.cod_moneda cod_moneda, cl.cod_persona cod_persona, cc.nro_cuenta nro_cuenta,
           de.nro_cheque nro_cheque, de.fecha fec_devolucion, de.hora hor_devolucion,
           de.sal_multa sal_multa, nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) saldo
      from cc_cta_corrientes cc,
           cc_che_devueltos de,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       --and cl.relacion = 'P'          --cualquier firmante
       and cc.estado not in ('X','A','C','P')
       and de.nro_cuenta = cc.nro_cuenta
       and tipo = 'I'
       and de.fecha = v_fcdehoy
       --and de.sal_multa = de.multa  --no se debitó nada de la multa
       --and de.multa > 0 --pero tiene multa
       and nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0) <= 0 --saldo 0 o sobregiro
       and exists (select 0
                     from cc_che_dev_firmantes c
                    where c.nro_cuenta = de.nro_cuenta
                      and c.nro_cheque = de.nro_cheque
                      and c.cod_persona = cl.cod_persona)
       and exists (select 0
                     from cc_che_dev_totales d, cc_che_dev_firmantes f
                    where d.cod_persona = f.cod_persona
                      and d.tipo = 'I'
                      and d.cantidad between 1 and 4
                      and f.nro_cuenta = de.nro_cuenta
                      and f.nro_cheque = de.nro_cheque
                      and de.fec_insercion >= nvl(d.fec_ult_regularizacion,sysdate-9999))
       /*and exists (Select nvl(cantidad,0) --alguno de los firmantes
                     from cc_che_dev_totales x, cc_che_dev_firmantes z, ge_cta_clientes y
                    where de.nro_cuenta = z.nro_cuenta
                      and de.nro_cheque = z.nro_cheque
                      and x.cod_persona = z.cod_persona
                      and y.cod_persona = z.cod_persona
                      and y.nro_cuenta  = z.nro_cuenta
                      and x.tipo = 'I'
                      and cantidad < 10 \*fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA')*\)*/
--       and cc.nro_cuenta not in (select ref_cuentas
/*         and  not exists  (select 0
                             from ge_telegramas
                            where cod_persona = cl.cod_persona
                              and fec_entrega is null
                              and cod_causa = 105 )*/
  order by cc.cod_moneda, cl.cod_persona, cc.nro_cuenta, de.nro_cheque;
  v_cod_causa number(3) := 105;
  v_cod_moneda varchar2(4) :=  'x';
  v_cod_persona varchar2(10) := '-1';
  v_ref_cuentas varchar2(1000) := null;
  v_cod_telegrama number;
  v_nro_cuenta   varchar2(20);
  v_generar varchar2(1) := 'S';
  v_saldo ge_telegramas.saldo%type :=0;
begin
   for de in insuf_sobregiro loop
      --verificar q la cuenta no tenga transacción prohibida
      If pag_cta.fu_ver_tra_prohibida(de.nro_cuenta,1000,4,41) = 'N' then
         if v_cod_moneda <> de.cod_moneda then
            if v_cod_moneda <> 'x' then
               -- corte por moneda
               select s_cod_telegrama.nextval into v_cod_telegrama from dual;
               insert into ge_telegramas
                  ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
               values
                  (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
               -- actualizo los detalles ya generados
               update ge_telegramas_det
                 set cod_telegrama = v_cod_telegrama
               where cod_telegrama = -1;
            end if;
            v_cod_moneda := de.cod_moneda;
            v_ref_cuentas := null;
            v_cod_persona := de.cod_persona;
            v_nro_cuenta := null;
            -- cerar saldo de la cuenta
            v_saldo := 0;
         end if;
         if v_cod_persona <> de.cod_persona then
             -- corte por persona
             select s_cod_telegrama.nextval into v_cod_telegrama from dual;
             insert into ge_telegramas
                 ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
             values
                 (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
             -- actualizo los detalles ya generados
             update ge_telegramas_det
                set cod_telegrama = v_cod_telegrama
              where cod_telegrama = -1;
             v_ref_cuentas := null;
             v_cod_persona := de.cod_persona;
             v_nro_cuenta := null;
             -- cerar saldo de la cuenta
             v_saldo := 0;
         end if;
         -- concateno las cuentas
         if nvl(v_nro_cuenta,'x') <> de.nro_cuenta then
            select decode(v_ref_cuentas,null,null,v_ref_cuentas||',') || de.nro_cuenta
              into v_ref_cuentas
              from dual;
            --sumar saldo de la cuenta
         end if;
         -- inserto detalles
         insert into ge_telegramas_det
             (cod_telegrama, nro_cuenta, nro_cheque, fecha, hora)
         values
             (-1, de.nro_cuenta, de.nro_cheque, de.fec_devolucion, de.hor_devolucion);
          v_nro_cuenta := de.nro_cuenta;
      else
         v_generar := 'N';--no generar x transacción prohibida
      end if;
   end loop;
   -- ultimo corte
   if v_generar <> 'N' then
      if v_cod_moneda <> 'x' then
         -- corte por moneda
         select s_cod_telegrama.nextval into v_cod_telegrama from dual;
         insert into ge_telegramas
            ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
         values
            (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
         -- actualizo los detalles ya generados
         update ge_telegramas_det
           set cod_telegrama = v_cod_telegrama
         where cod_telegrama = -1;
      end if;
   end if;
end;

--genera telegrama 106
--10 DEV.INSF.FOND.-CIER.CTA. ART 1425
procedure lp_gen_telegrama_106 is
  cursor insuf_sobregiro is --falta saldo y multa
    select cc.cod_moneda cod_moneda, cl.cod_persona cod_persona, cc.nro_cuenta nro_cuenta,
           de.nro_cheque nro_cheque, de.fecha fec_devolucion, de.hora hor_devolucion,
           de.sal_multa sal_multa, nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) saldo
      from cc_cta_corrientes cc,
           cc_che_devueltos de,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       --and cl.relacion = 'P'          --cualquier firmante
       and cc.estado not in ('X','A','C','P')
       and de.nro_cuenta = cc.nro_cuenta
       and tipo = 'I'
       and exists (select 0 from cc_che_devueltos x
                    where x.nro_cuenta = cc.nro_cuenta
                      and x.fecha = v_fcdehoy)
       /*and de.sal_multa = de.multa  --no se debitó nada de la multa
       and de.multa > 0 --pero tiene multa*/
       and exists (select 0
                     from cc_che_dev_firmantes c
                    where c.nro_cuenta = de.nro_cuenta
                      and c.nro_cheque = de.nro_cheque
                      and c.cod_persona = cl.cod_persona)
       and exists (select 0
                     from cc_che_dev_totales d, cc_che_dev_firmantes f
                    where d.cod_persona = f.cod_persona
                      and d.tipo = 'I'
                      and d.cantidad >=  10 --fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA')
                      and f.nro_cuenta = de.nro_cuenta
                      and f.nro_cheque = de.nro_cheque
                      and de.fec_insercion >= nvl(d.fec_ult_regularizacion,sysdate-9999))
       /*and exists (Select nvl(cantidad,0) --alguno de los firmantes
                     from cc_che_dev_totales x, cc_che_dev_firmantes z, ge_cta_clientes y
                    where de.nro_cuenta = z.nro_cuenta
                      and de.nro_cheque = z.nro_cheque
                      and x.cod_persona = z.cod_persona
                      and y.cod_persona = z.cod_persona
                      and y.nro_cuenta  = z.nro_cuenta
                      and x.tipo = 'I'
                      and cantidad < 10 \*fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA')*\)*/
/*       and not exists (select '1'
                         from cc_sobregiros_res
                        where nro_cuenta = cc.nro_cuenta )*/
--       and cc.nro_cuenta not in (select ref_cuentas
         and  not exists  (select 0
                             from ge_telegramas
                            where cod_persona = cl.cod_persona
                              and fec_entrega is null
                              and cod_causa = 106 )
  order by cc.cod_moneda, cl.cod_persona, cc.nro_cuenta, de.nro_cheque;
  v_cod_causa number(3) := 106;
  v_cod_moneda varchar2(4) :=  'x';
  v_cod_persona varchar2(10) := '-1';
  v_ref_cuentas varchar2(1000) := null;
  v_cod_telegrama number;
  v_nro_cuenta   varchar2(20);
  v_generar varchar2(1) := 'S';
  v_saldo ge_telegramas.saldo%type :=0;
begin
   for de in insuf_sobregiro loop
      --verificar q la cuenta no tenga transacción prohibida
      If pag_cta.fu_ver_tra_prohibida(de.nro_cuenta,1000,4,41) = 'N' then
         if v_cod_moneda <> de.cod_moneda then
            if v_cod_moneda <> 'x' then
               -- corte por moneda
               select s_cod_telegrama.nextval into v_cod_telegrama from dual;
               insert into ge_telegramas
                  ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
               values
                  (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
               -- actualizo los detalles ya generados
               update ge_telegramas_det
                 set cod_telegrama = v_cod_telegrama
               where cod_telegrama = -1;
            end if;
            v_cod_moneda := de.cod_moneda;
            v_ref_cuentas := null;
            v_cod_persona := de.cod_persona;
            v_nro_cuenta := null;
            -- cerar saldo de la cuenta
            v_saldo := 0;
         end if;
         if v_cod_persona <> de.cod_persona then
             -- corte por persona
             select s_cod_telegrama.nextval into v_cod_telegrama from dual;
             insert into ge_telegramas
                 ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
             values
                 (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
             -- actualizo los detalles ya generados
             update ge_telegramas_det
                set cod_telegrama = v_cod_telegrama
              where cod_telegrama = -1;
             v_ref_cuentas := null;
             v_cod_persona := de.cod_persona;
             v_nro_cuenta := null;
             -- cerar saldo de la cuenta
             v_saldo := 0;
         end if;
         -- concateno las cuentas
         if nvl(v_nro_cuenta,'x') <> de.nro_cuenta then
            select decode(v_ref_cuentas,null,null,v_ref_cuentas||',') || de.nro_cuenta
              into v_ref_cuentas
              from dual;
            --sumar saldo de la cuenta
         end if;
         -- inserto detalles
         insert into ge_telegramas_det
             (cod_telegrama, nro_cuenta, nro_cheque, fecha, hora)
         values
             (-1, de.nro_cuenta, de.nro_cheque, de.fec_devolucion, de.hor_devolucion);
          v_nro_cuenta := de.nro_cuenta;
      else
         v_generar := 'N';--no generar x transacción prohibida
      end if;
   end loop;
   -- ultimo corte
   if v_generar <> 'N' then
      if v_cod_moneda <> 'x' then
         -- corte por moneda
         select s_cod_telegrama.nextval into v_cod_telegrama from dual;
         insert into ge_telegramas
            ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
         values
            (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
         -- actualizo los detalles ya generados
         update ge_telegramas_det
           set cod_telegrama = v_cod_telegrama
         where cod_telegrama = -1;
      end if;
   end if;
end;
--genera telegrama 107
--5DEV.CHEQ. X IF-SIN SOB-INTIM.MULTA, si no pagó nada
procedure lp_gen_telegrama_107 is
  cursor datos is --multa
    select cc.cod_moneda cod_moneda, cl.cod_persona cod_persona, cc.nro_cuenta nro_cuenta,
           de.nro_cheque nro_cheque, de.fecha fec_devolucion, de.hora hor_devolucion,
           de.sal_multa sal_multa
      from cc_cta_corrientes cc,
           cc_che_devueltos de,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       --and cl.relacion = 'P'          --cualquier firmante
       and cc.estado not in ('X','A','C','P')
       and de.nro_cuenta = cc.nro_cuenta
       and tipo = 'I'
       and exists (select 0 from cc_che_devueltos x
                    where x.nro_cuenta = cc.nro_cuenta
                      and x.fecha = v_fcdehoy)
       --and de.sal_multa = de.multa  --no se debitó nada de la multa
       --and de.multa > 0
       and nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0) = 0 --saldo 0
       and exists (select 0
                     from cc_che_dev_firmantes c
                    where c.nro_cuenta = de.nro_cuenta
                      and c.nro_cheque = de.nro_cheque
                      and c.cod_persona = cl.cod_persona)
       and exists (select 0
                     from cc_che_dev_totales d, cc_che_dev_firmantes f
                    where d.cod_persona = f.cod_persona
                      and d.tipo = 'I'
                      and (d.cantidad >= 5 and d.cantidad < 10)
                      and f.nro_cuenta = de.nro_cuenta
                      and f.nro_cheque = de.nro_cheque
                      and de.fec_insercion >= nvl(d.fec_ult_regularizacion,sysdate-9999))
       /*and exists (Select nvl(cantidad,0) --alguno de los firmantes
                     from cc_che_dev_totales x, cc_che_dev_firmantes z, ge_cta_clientes y
                    where de.nro_cuenta = z.nro_cuenta
                      and de.nro_cheque = z.nro_cheque
                      and x.cod_persona = z.cod_persona
                      and y.cod_persona = z.cod_persona
                      and y.nro_cuenta  = z.nro_cuenta
                      and x.tipo = 'I'
                      and cantidad < 10 \*fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA')*\)*/
       and not exists (select '1'
                         from cc_sobregiros_res
                        where nro_cuenta = cc.nro_cuenta )
--       and cc.nro_cuenta not in (select ref_cuentas
         and  not exists  (select 0
                             from ge_telegramas
                            where cod_persona = cl.cod_persona
                              and fec_entrega is null
                              and cod_causa in (107,106) )
  order by cc.cod_moneda, cl.cod_persona, cc.nro_cuenta, de.nro_cheque;
  v_cod_causa number(3) := 107;
  v_cod_moneda varchar2(4) :=  'x';
  v_cod_persona varchar2(10) := '-1';
  v_ref_cuentas varchar2(1000) := null;
  v_cod_telegrama number;
  v_nro_cuenta   varchar2(20);
  v_generar varchar2(1) := 'S';
  v_saldo ge_telegramas.saldo%type :=0;
begin
   for de in datos loop
      --verificar q la cuenta no tenga transacción prohibida
      If pag_cta.fu_ver_tra_prohibida(de.nro_cuenta,1000,4,41) = 'N' then
         if v_cod_moneda <> de.cod_moneda then
            if v_cod_moneda <> 'x' then
               -- corte por moneda
               select s_cod_telegrama.nextval into v_cod_telegrama from dual;
               insert into ge_telegramas
                  ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
               values
                  (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
               -- actualizo los detalles ya generados
               update ge_telegramas_det
                 set cod_telegrama = v_cod_telegrama
               where cod_telegrama = -1;
            end if;
            v_cod_moneda := de.cod_moneda;
            v_ref_cuentas := null;
            v_cod_persona := de.cod_persona;
            v_nro_cuenta := null;
            -- cerar saldo de la cuenta
            v_saldo := 0;
         end if;
         if v_cod_persona <> de.cod_persona then
             -- corte por persona
             select s_cod_telegrama.nextval into v_cod_telegrama from dual;
             insert into ge_telegramas
                 ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
             values
                 (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
             -- actualizo los detalles ya generados
             update ge_telegramas_det
                set cod_telegrama = v_cod_telegrama
              where cod_telegrama = -1;
             v_ref_cuentas := null;
             v_cod_persona := de.cod_persona;
             v_nro_cuenta := null;
             -- cerar saldo de la cuenta
             v_saldo := 0;
         end if;
         -- concateno las cuentas
         if nvl(v_nro_cuenta,'x') <> de.nro_cuenta then
            select decode(v_ref_cuentas,null,null,v_ref_cuentas||',') || de.nro_cuenta
              into v_ref_cuentas
              from dual;
            --sumar saldo de la cuenta
         end if;
         -- inserto detalles
         insert into ge_telegramas_det
             (cod_telegrama, nro_cuenta, nro_cheque, fecha, hora)
         values
             (-1, de.nro_cuenta, de.nro_cheque, de.fec_devolucion, de.hor_devolucion);
          v_nro_cuenta := de.nro_cuenta;
      else
         v_generar := 'N';--no generar x transacción prohibida
      end if;
   end loop;
   -- ultimo corte
   if v_generar <> 'N' then
      if v_cod_moneda <> 'x' then
         -- corte por moneda
         select s_cod_telegrama.nextval into v_cod_telegrama from dual;
         insert into ge_telegramas
            ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
         values
            (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
         -- actualizo los detalles ya generados
         update ge_telegramas_det
           set cod_telegrama = v_cod_telegrama
         where cod_telegrama = -1;
      end if;
   end if;
end;
--genera telegrama 108
--5DEV.CHEQ. X IF-SIN SOB-DEB.MULTA,de haberse debitado algo
procedure lp_gen_telegrama_108 is
  cursor insuf_sobregiro is -- falta el saldo
    select cc.cod_moneda cod_moneda, cl.cod_persona cod_persona, cc.nro_cuenta nro_cuenta,
           de.nro_cheque nro_cheque, de.fecha fec_devolucion, de.hora hor_devolucion,
           de.sal_multa sal_multa
      from cc_cta_corrientes cc,
           cc_che_devueltos de,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       --and cl.relacion = 'P'          --cualquier firmante
       and cc.estado not in ('X','A','C','P')
       and de.nro_cuenta = cc.nro_cuenta
       and tipo = 'I'
       and exists (select 0 from cc_che_devueltos x
                    where x.nro_cuenta = cc.nro_cuenta
                      and x.fecha = v_fcdehoy)
       --and de.sal_multa < de.multa  --se debitó algo de la multa
       and nvl(sal_total,0) - nvl(sal_retenido,0) - nvl(sal_bloqueado,0) > 0 --con saldo
       and exists (select 0
                     from cc_che_dev_firmantes c
                    where c.nro_cuenta = de.nro_cuenta
                      and c.nro_cheque = de.nro_cheque
                      and c.cod_persona = cl.cod_persona)
       and exists (select 0
                     from cc_che_dev_totales d, cc_che_dev_firmantes f
                    where d.cod_persona = f.cod_persona
                      and d.tipo = 'I'
                      and (d.cantidad >= 5 and d.cantidad < 10)
                      and f.nro_cuenta = de.nro_cuenta
                      and f.nro_cheque = de.nro_cheque
                      and de.fec_insercion >= nvl(d.fec_ult_regularizacion,sysdate-9999))
       /*and exists (Select nvl(cantidad,0) --alguno de los firmantes
                     from cc_che_dev_totales x, cc_che_dev_firmantes z, ge_cta_clientes y
                    where de.nro_cuenta = z.nro_cuenta
                      and de.nro_cheque = z.nro_cheque
                      and x.cod_persona = z.cod_persona
                      and y.cod_persona = z.cod_persona
                      and y.nro_cuenta  = z.nro_cuenta
                      and x.tipo = 'I'
                      and cantidad < 10 \*fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA')*\)*/
       and not exists (select '1'
                         from cc_sobregiros_res
                        where nro_cuenta = cc.nro_cuenta )
--       and cc.nro_cuenta not in (select ref_cuentas
         and  not exists  (select 0
                             from ge_telegramas
                            where cod_persona = cl.cod_persona
                              and fec_entrega is null
                              and cod_causa in ( 108,106) )
  order by cc.cod_moneda, cl.cod_persona, cc.nro_cuenta, de.nro_cheque;
  v_cod_causa number(3) := 108;
  v_cod_moneda varchar2(4) :=  'x';
  v_cod_persona varchar2(10) := '-1';
  v_ref_cuentas varchar2(1000) := null;
  v_cod_telegrama number;
  v_nro_cuenta   varchar2(20);
  v_generar varchar2(1) := 'S';
  v_saldo ge_telegramas.saldo%type :=0;
begin
   for de in insuf_sobregiro loop
      --verificar q la cuenta no tenga transacción prohibida
      If pag_cta.fu_ver_tra_prohibida(de.nro_cuenta,1000,4,41) = 'N' then
         if v_cod_moneda <> de.cod_moneda then
            if v_cod_moneda <> 'x' then
               -- corte por moneda
               select s_cod_telegrama.nextval into v_cod_telegrama from dual;
               insert into ge_telegramas
                  ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
               values
                  (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
               -- actualizo los detalles ya generados
               update ge_telegramas_det
                 set cod_telegrama = v_cod_telegrama
               where cod_telegrama = -1;
            end if;
            v_cod_moneda := de.cod_moneda;
            v_ref_cuentas := null;
            v_cod_persona := de.cod_persona;
            v_nro_cuenta := null;
            -- cerar saldo de la cuenta
            v_saldo := 0;
         end if;
         if v_cod_persona <> de.cod_persona then
             -- corte por persona
             select s_cod_telegrama.nextval into v_cod_telegrama from dual;
             insert into ge_telegramas
                 ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
             values
                 (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
             -- actualizo los detalles ya generados
             update ge_telegramas_det
                set cod_telegrama = v_cod_telegrama
              where cod_telegrama = -1;
             v_ref_cuentas := null;
             v_cod_persona := de.cod_persona;
             v_nro_cuenta := null;
             -- cerar saldo de la cuenta
             v_saldo := 0;
         end if;
         -- concateno las cuentas
         if nvl(v_nro_cuenta,'x') <> de.nro_cuenta then
            select decode(v_ref_cuentas,null,null,v_ref_cuentas||',') || de.nro_cuenta
              into v_ref_cuentas
              from dual;
            --sumar saldo de la cuenta
         end if;
         -- inserto detalles
         insert into ge_telegramas_det
             (cod_telegrama, nro_cuenta, nro_cheque, fecha, hora)
         values
             (-1, de.nro_cuenta, de.nro_cheque, de.fec_devolucion, de.hor_devolucion);
          v_nro_cuenta := de.nro_cuenta;
      else
         v_generar := 'N';--no generar x transacción prohibida
      end if;
   end loop;
   -- ultimo corte
   if v_generar <> 'N' then
      if v_cod_moneda <> 'x' then
         -- corte por moneda
         select s_cod_telegrama.nextval into v_cod_telegrama from dual;
         insert into ge_telegramas
            ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda)
         values
            (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda);
         -- actualizo los detalles ya generados
         update ge_telegramas_det
           set cod_telegrama = v_cod_telegrama
         where cod_telegrama = -1;
      end if;
   end if;
end;
--genera telegrama 117
--5 DEV. X INSUF.FOND-INTIM.MULTA-SOB
procedure lp_gen_telegrama_117 is
  cursor insuf_sobregiro is --falta saldo y multa
    select cc.cod_moneda cod_moneda, cl.cod_persona cod_persona, cc.nro_cuenta nro_cuenta,
           de.nro_cheque nro_cheque, de.fecha fec_devolucion, de.hora hor_devolucion,
           de.sal_multa sal_multa, nvl(cc.sal_total,0) - nvl(cc.sal_retenido,0) saldo
      from cc_cta_corrientes cc,
           cc_che_devueltos de,
           ge_cta_clientes cl
     where cc.nro_cuenta = cl.nro_cuenta
       --and cl.relacion = 'P'          --cualquier firmante
       and cc.estado not in ('X','A','C','P')
       and de.nro_cuenta = cc.nro_cuenta
       and tipo = 'I'
       and exists (select 0 from cc_che_devueltos x
                    where x.nro_cuenta = cc.nro_cuenta
                      and x.fecha = v_fcdehoy)
       --and de.sal_multa > 0 --con saldo de multa
       and exists (select '1' --está en sobregiro
                     from cc_sobregiros_res
                    where nro_cuenta = cc.nro_cuenta )
       and exists (select 0
                     from cc_che_dev_firmantes c
                    where c.nro_cuenta = de.nro_cuenta
                      and c.nro_cheque = de.nro_cheque
                      and c.cod_persona = cl.cod_persona)
       and exists (select 0
                     from cc_che_dev_totales d, cc_che_dev_firmantes f
                    where d.cod_persona = f.cod_persona
                      and d.tipo = 'I'
                      and (d.cantidad >= 5 and d.cantidad < 10)
                      and f.nro_cuenta = de.nro_cuenta
                      and f.nro_cheque = de.nro_cheque
                      and de.fec_insercion >= nvl(d.fec_ult_regularizacion,sysdate-9999))
       /*and exists (Select nvl(cantidad,0) --alguno de los firmantes
                     from cc_che_dev_totales x, cc_che_dev_firmantes z, ge_cta_clientes y
                    where de.nro_cuenta = z.nro_cuenta
                      and de.nro_cheque = z.nro_cheque
                      and x.cod_persona = z.cod_persona
                      and y.cod_persona = z.cod_persona
                      and y.nro_cuenta  = z.nro_cuenta
                      and x.tipo = 'I'
                      and cantidad < 10 \*fug_obt_pardinamico('CAN_FAL_INSUFICIENCIA')*\)*/
--       and cc.nro_cuenta not in (select ref_cuentas
         and  not exists  (select 0
                             from ge_telegramas
                            where cod_persona = cl.cod_persona
                              and fec_entrega is null
                              and cod_causa in (117,106) )
  order by cc.cod_moneda, cl.cod_persona, cc.nro_cuenta, de.nro_cheque;
  v_cod_causa number(3) := 117;
  v_cod_moneda varchar2(4) :=  'x';
  v_cod_persona varchar2(10) := '-1';
  v_ref_cuentas varchar2(1000) := null;
  v_cod_telegrama number;
  v_nro_cuenta   varchar2(20);
  v_generar varchar2(1) := 'S';
  v_saldo ge_telegramas.saldo%type :=0;
begin
   for de in insuf_sobregiro loop
      --verificar q la cuenta no tenga transacción prohibida
      If pag_cta.fu_ver_tra_prohibida(de.nro_cuenta,1000,4,41) = 'N' then
         if v_cod_moneda <> de.cod_moneda then
            if v_cod_moneda <> 'x' then
               -- corte por moneda
               select s_cod_telegrama.nextval into v_cod_telegrama from dual;
               insert into ge_telegramas
                  ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda, saldo)
               values
                  (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda, v_saldo);
               -- actualizo los detalles ya generados
               update ge_telegramas_det
                 set cod_telegrama = v_cod_telegrama
               where cod_telegrama = -1;
            end if;
            v_cod_moneda := de.cod_moneda;
            v_ref_cuentas := null;
            v_cod_persona := de.cod_persona;
            v_nro_cuenta := null;
            -- cerar saldo de la cuenta
            v_saldo := 0;
         end if;
         if v_cod_persona <> de.cod_persona then
             -- corte por persona
             select s_cod_telegrama.nextval into v_cod_telegrama from dual;
             insert into ge_telegramas
                 ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda, saldo)
             values
                 (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda, v_saldo);
             -- actualizo los detalles ya generados
             update ge_telegramas_det
                set cod_telegrama = v_cod_telegrama
              where cod_telegrama = -1;
             v_ref_cuentas := null;
             v_cod_persona := de.cod_persona;
             v_nro_cuenta := null;
             -- cerar saldo de la cuenta
             v_saldo := 0;
         end if;
         -- concateno las cuentas
         if nvl(v_nro_cuenta,'x') <> de.nro_cuenta then
            select decode(v_ref_cuentas,null,null,v_ref_cuentas||',') || de.nro_cuenta
              into v_ref_cuentas
              from dual;
            --sumar saldo de la cuenta
            v_saldo := v_saldo + de.saldo;
         end if;
         -- inserto detalles
         insert into ge_telegramas_det
             (cod_telegrama, nro_cuenta, nro_cheque, fecha, hora)
         values
             (-1, de.nro_cuenta, de.nro_cheque, de.fec_devolucion, de.hor_devolucion);
          v_nro_cuenta := de.nro_cuenta;
      else
         v_generar := 'N';--no generar x transacción prohibida
      end if;
   end loop;
   -- ultimo corte
   if v_generar <> 'N' then
      if v_cod_moneda <> 'x' then
         -- corte por moneda
         select s_cod_telegrama.nextval into v_cod_telegrama from dual;
         insert into ge_telegramas
            ( cod_telegrama, ref_cuentas, cod_causa, fec_generacion, cod_persona, estado, cod_moneda, saldo)
         values
            (v_cod_telegrama, v_ref_cuentas, v_cod_causa, V_FCDEHOY, v_cod_persona, 'G', v_cod_moneda, v_saldo);
         -- actualizo los detalles ya generados
         update ge_telegramas_det
           set cod_telegrama = v_cod_telegrama
         where cod_telegrama = -1;
      end if;
   end if;
end;
--PROCESO PRINCIPAL--
begin
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  --siempre verifica si tiene transacción prohibida para no generar el telegrama
  --Procesa causal 101 :Saldo cero y sin movimientos por 90 dias
  for i in saldo_101 loop
    If pag_cta.fu_ver_tra_prohibida(i.nro_cuenta,1000,4,41) = 'N' then
      lp_ins_telegrama(i.nro_cuenta,101,v_fcdehoy,i.cod_persona,'G',i.saldo,i.cod_moneda,null);
    End if;
  end loop;
  --Procesa causal 116 :Sobregiro de 30 dias
  for i in sobregiro_116 loop
    If pag_cta.fu_ver_tra_prohibida(i.nro_cuenta,1000,4,41) = 'N' then
      lp_ins_telegrama(i.nro_cuenta,116,v_fcdehoy,i.cod_persona,'G',i.saldo,i.cod_moneda,null);
    End if;
  end loop;
  --Procesa causal 112 :Cuentas canceladas del dia. art 1425
  --Procesa causal 113: Cuentas canceladas del dia. ley
  for i in cancelacion_112_113 loop
    If pag_cta.fu_ver_tra_prohibida(i.nro_cuenta,1000,4,41) = 'N' then
      lp_ins_telegrama(i.nro_cuenta,i.causa,v_fcdehoy,i.cod_persona,'G',i.saldo,i.cod_moneda,null);
    End if;
  end loop;
  --Procesa causal 110 :cta.cancelada - saldo deudor ley 2835/05
  --Procesa causal 111 :cta.cancelada - saldo deudor art 1524
  for i in cancelacion_deudor_110_111 loop
    If pag_cta.fu_ver_tra_prohibida(i.nro_cuenta,1000,4,41) = 'N' then
      lp_ins_telegrama(i.nro_cuenta,i.causa,v_fcdehoy,i.cod_persona,'G',i.saldo,i.cod_moneda,null);
    End if;
  end loop;

  --CHEQUES--------
  --Procesa causal 104 :dev.cheq x insuf.fondos - débito de multa
  --DEV.CHEQ X INSUF.FONDOS-DEB.MULTA
  lp_gen_telegrama_104;

  --Procesa causal 105 :dev.cheq x insuf.fond.-intimación a pago de multa
  --DEV.CHEQ X INSUF.FOND.-INTIM.MULTA
  lp_gen_telegrama_105;

  --Procesa causal 106 :10 dev.insf.fond. - cierre cta. art. 1425, no pagó nada de multa
  --10 DEV.INSF.FOND.-CIER.CTA. ART 1425
  lp_gen_telegrama_106;

  --Procesa causal 107 : 5 Devoluciones de cheques por insuf. de fondos (sin sobregiro). intimación pago
  -- 107	5DEV.CHEQ. X IF-SIN SOB-INTIM.MULTA
  lp_gen_telegrama_107;

  --Procesa causal 108 : 5 Devoluciones de cheques por insuf. de fondos (sin sobregiro), débito de multa
  -- 108	5DEV.CHEQ. X IF-SIN SOB-DEB.MULTA
  lp_gen_telegrama_108;

  --Procesa causal 117 :5 dev. x insuf.fondo - intimación a pago de multa - en sobregiro
  --5 DEV. X INSUF.FOND-INTIM.MULTA-SOB
  lp_gen_telegrama_117;

exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Generación de telegramas '||sqlerrm);
    End if;
end;
/

