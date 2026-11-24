CREATE OR REPLACE PROCEDURE IT.PRP_REV_GAN_RES4
(p_fecha in date default null,
p_hora in varchar2 default null,
p_cod_usuario in varchar2 default null,
p_nro_cuenta in varchar2 default null,
p_nro_solicitud in varchar2 default null,
p_act_inventario in varchar2 default 'N')

IS
--Genera Movimiento contrario para Gastos de Cobranza y
-- interes devengado en suspenso
--cancelación de prestamos resolucion 4 BCP
--Tambien Carga Tabla de Inventario para estas cuentas

v_fec_actual DATE := pag_cal.fu_obt_fec_actual(6);
v_fec_pri_habil DATE ;
v_nro_cuenta GE_cuentas.nro_cuenta%type;
v_fec_valor date;
v_fecha date;
v_lugar varchar2(3000);
v_hora  ge_movimientos.hora%type := to_char(sysdate, 'HH24:MI:SS');
v_hora_mov ge_movimientos.hora%type := to_char(sysdate, 'HH24:MI:SS');
v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
v_mon_ges_cobro number(18,2);
v_mon_ges_impuesto number(18,2);
v_mon_cargo number(18,2);
v_cod_mon_local        varchar2(10):=pag_gen.FU_OBT_MON_LOCAL;
v_max_secuencia number(18);
v_mto_dev_suspenso number(18,2);
v_mto_sobregiro number(18,2);
v_nro_sol_nueva number(18);
v_nro_sec_ultimo number(18);
v_mon_ges_sobregiro number(18,2);
--
v_cod_rubro_cob_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_COB_RE4',null,null,'GS', null,null);
v_cod_rubro_cob_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_COB_RE4',null,null,'USD', null,null);
v_cod_rubro_int_sus_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_SUS_RE4',null,null,'GS', null,null);
v_cod_rubro_int_sus_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_SUS_RE4',null,null,'USD', null,null);
--
v_tie_cobranza VARCHAR2(1):='N';
v_tie_dev_suspenso VARCHAR2(1):='N';
v_tie_sobregiro VARCHAR2(1):='N';
--
v_cod_rubro_sob_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_SOB_RE4',null,null,'GS', null,null);
v_cod_rubro_sob_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_SOB_RE4',null,null,'USD', null,null);

---Movimientos para reversion de cobranza
cursor c_movimientos is
select a.*
    from ge_movimientos a
         where a.fecha = v_fecha
           and a.cod_transaccion =7712
           and a.cod_modulo = 6
           and a.reversado = 'N'
           and a.monto > 0
           and a.cod_tra_padre in (359,360)
           and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
           and a.hora=nvl(p_hora,a.hora)
           and a.cod_usuario= nvl(p_cod_usuario,a.cod_usuario)
           and (exists (select 1 from
                        PR_CTA_PRE_CAN_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha))
                or  exists (select 1 from
                        PR_CTA_PRE_REF_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha)) )
            order by a.nro_cuenta;

cursor c_mov_int_dev is
select a.*
    from ge_movimientos a
         where a.fecha = v_fecha
           and a.cod_modulo = 6
           and a.reversado = 'N'
           and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
           and a.hora=nvl(p_hora,a.hora)
           and a.cod_usuario= nvl(p_cod_usuario,a.cod_usuario)
           and a.monto > 0
           and a.cod_tra_padre =900
           and (exists (select 1 from
                        PR_CTA_PRE_CAN_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha))
                or  exists (select 1 from
                        PR_CTA_PRE_REF_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha)))
            order by a.nro_cuenta;


---Movimientos de sobregiro
cursor c_movimientos_s is
select a.*
    from ge_movimientos a
         where a.fecha = v_fecha
           and a.cod_transaccion =550
           and a.cod_modulo = 4
           and a.reversado = 'N'
           and a.monto > 0
           and a.cod_tra_padre =550
           and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
           and a.hora=nvl(p_hora,a.hora)
           and a.cod_usuario= nvl(p_cod_usuario,a.cod_usuario)
           and (exists (select 1 from
                        PR_CTA_PRE_CAN_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha))
                or  exists (select 1 from
                        PR_CTA_PRE_REF_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha)) )
            order by a.nro_cuenta;
--Para dias anteriores
---Movimientos para reversion de cobranza
cursor c_movimientos_his is
select a.*
    from pr_movimientos_his a
         where a.fecha = v_fecha
           and a.cod_transaccion =7712
           and a.cod_modulo = 6
           and a.reversado = 'N'
           and a.monto > 0
           and a.cod_tra_padre in (359,360)
           and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
           and a.hora=nvl(p_hora,a.hora)
           and a.cod_usuario= nvl(p_cod_usuario,a.cod_usuario)
           and (exists (select 1 from
                        PR_CTA_PRE_CAN_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha))
                or  exists (select 1 from
                        PR_CTA_PRE_REF_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha)) )
            order by a.nro_cuenta;

cursor c_movimientos_sob_his is
select a.*
    from ge_movimientos a
         where a.fecha = v_fecha
           and a.cod_transaccion =550
           and a.cod_modulo = 4
           and a.reversado = 'N'
           and a.monto > 0
           and a.cod_tra_padre =550
           and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
           and a.hora=nvl(p_hora,a.hora)
           and a.cod_usuario= nvl(p_cod_usuario,a.cod_usuario)
           and (exists (select 1 from
                        PR_CTA_PRE_CAN_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha))
                or  exists (select 1 from
                        PR_CTA_PRE_REF_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha)) )
            order by a.nro_cuenta;
cursor c_mov_int_dev_his is
select a.*
    from pr_movimientos_his a
         where a.fecha = v_fecha
           and a.cod_modulo = 6
           and a.reversado = 'N'
           and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
           and a.hora=nvl(p_hora,a.hora)
           and a.cod_usuario= nvl(p_cod_usuario,a.cod_usuario)
           and a.monto > 0
           and a.cod_tra_padre =900
           and (exists (select 1 from
                        PR_CTA_PRE_CAN_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha))
                or  exists (select 1 from
                        PR_CTA_PRE_REF_RES4 b
                         where b.nro_cuenta= a.nro_cuenta
                         and trunc(b.fec_proceso)= trunc(a.fecha)))
            order by a.nro_cuenta;


--Tablas Espejo

CURSOR c_cur_datos_1 IS
 select a.nro_cuenta nro_cuenta, a.fec_insercion fec_insercion,a.usu_insercion usu_insercion, a.nro_secuencia,
    a.mto_dev_suspenso, a.mto_mora,a.mto_mor_int,a.mto_punitorio
   from pr_cta_pre_can_res4 a
    where a.fec_proceso= trunc(v_fec_actual)
       and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
       and a.nro_secuencia= nvl(v_nro_sec_ultimo,null);

CURSOR c_cur_datos_2 IS
 select a.nro_cuenta nro_cuenta, a.fec_insercion fec_insercion,a.usu_insercion usu_insercion,a.nro_sol_nueva,
 a.mto_dev_suspenso, a.sal_inv_sobregiro, a.inv_sobregiro
   from PR_CTA_PRE_REF_RES4 a
   where a.fec_proceso= trunc(v_fec_actual)
    and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
     and a.nro_sol_nueva= nvl(v_nro_sol_nueva,a.nro_sol_nueva);


BEGIN
   v_lugar:='Cuenta: '||p_nro_cuenta||' Sol:'||p_nro_solicitud;
   v_fecha:= null;
   v_fecha:= nvl(p_fecha, v_fec_actual);

   Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:= 1; pae_cnf.G_PROGRAMA := 'GPPROFIN';  End;
   v_hora := p_hora;
   v_max_secuencia:=0;
   v_nro_sol_nueva:=p_nro_solicitud;
   v_nro_sec_ultimo:=0;
   v_tie_cobranza:= 'N';
   v_tie_dev_suspenso:='N';
   v_tie_sobregiro:='N';
   v_lugar:='Proc.Ins.Mov.Re4: '|| p_nro_cuenta;
   PRP_INS_MOV_CAN_RES4(v_fecha,p_hora ,p_cod_usuario,p_nro_cuenta, p_nro_solicitud,nvl(p_act_inventario,'N'));
--Genera las reversiones de ganancia de la fecha actual
if v_fecha = v_fec_actual then
       --Obtenemos la máxima secuencia
          begin
           select max(a.nro_secuencia)
             into v_max_secuencia
             from ge_movimientos a
              where a.fecha=v_fecha
                and a.hora=p_hora
                and a.cod_usuario= user;
          exception
            when others then
              v_max_secuencia:=0;
          end;
      v_nro_secuencia := nvl(v_max_secuencia,0);
  ---Obtenemos los datos,para generar movimientos reversión
  begin
        select decode(a.inv_ges_cobranza,0,'N','S'),decode(a.inv_interes,0,'N','S'),decode(a.inv_sobregiro,0,'N','S')
               into v_tie_cobranza, v_tie_dev_suspenso, v_tie_sobregiro
                from  PR_CTA_PRE_REF_RES4 a
                  where a.fec_proceso= trunc(v_fecha)
                       and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
                        and a.nro_sol_nueva= nvl(v_nro_sol_nueva,a.nro_sol_nueva);
   exception
     when no_data_found then
       v_tie_cobranza:='N';
       v_tie_dev_suspenso:='N';
       v_tie_sobregiro:='N';
     when others then
       v_tie_cobranza:='N';
       v_tie_dev_suspenso:='N';
       v_tie_sobregiro:='N';
   end;
  --
  if NVL(v_tie_cobranza,'N') ='S'  then
     for i in c_movimientos loop
        v_lugar:='Reversando Cobranza:'||i.nro_cuenta;
        v_fec_valor := i.fec_valor;
        v_nro_cuenta := i.nro_cuenta;
        v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
        insert into ge_movimientos
                    (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                     cod_tra_padre,cod_transaccion,fecha,fec_valor,
                     monto,mto_equ_local, estado,concepto,reversado,
                     cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                     nro_secuencia,nro_cuenta,cod_ofi_origen,
                     cod_rubro,tip_mov_rubro, referencia, cod_persona,
                     est_cuenta,protegido,cotizacion,
                     nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
            values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                     i.cod_tra_padre,i.cod_transaccion,i.fecha,i.fec_valor,
                     i.monto * -1,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local * -1),i.estado,'Rev.Cobranza RES4 '||i.referencia,i.reversado,
                     i.cod_mod_padre,i.cod_mad_padre,user, v_hora,
                     v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                     i.cod_rubro,i.tip_mov_rubro,
                     i.referencia, i.cod_persona,
                     i.est_cuenta, i.protegido, i.cotizacion,
                     i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
           v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
           insert into ge_movimientos
                    (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                     cod_tra_padre,cod_transaccion,fecha,fec_valor,
                     monto,mto_equ_local, estado,concepto,reversado,
                     cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                     nro_secuencia,nro_cuenta,cod_ofi_origen,
                     cod_rubro,tip_mov_rubro, referencia, cod_persona,
                     est_cuenta,protegido,cotizacion,
                     nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
            values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                     i.cod_tra_padre,NULL/*i.cod_transaccion*/,i.fecha,i.fec_valor,
                     i.monto ,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local),i.estado,'Rev.Cobranza RES4 '||i.referencia,i.reversado,
                     i.cod_mod_padre,i.cod_mad_padre,user, v_hora,
                     v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                     decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_cob_gs,v_cod_rubro_cob_usd),'C',
                     i.referencia, i.cod_persona,
                     i.est_cuenta, i.protegido, i.cotizacion,
                     i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
     end loop;
   end if;
   if nvl(v_tie_dev_suspenso,'N') ='S'  then
    for i in c_mov_int_dev loop
      v_lugar:='Reversando Dev.Int.Susp.:'||i.nro_cuenta;
      v_fec_valor := i.fec_valor;
      v_nro_cuenta := i.nro_cuenta;
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
      --v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
      if i.tip_mov_rubro='C' then
        insert into ge_movimientos
                    (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                     cod_tra_padre,cod_transaccion,fecha,fec_valor,
                     monto,mto_equ_local, estado,concepto,reversado,
                     cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                     nro_secuencia,nro_cuenta,cod_ofi_origen,
                     cod_rubro,tip_mov_rubro,
                     referencia, cod_persona,
                     est_cuenta,protegido,cotizacion,
                     nro_documento,nro_documento2,nro_documento3,nro_documento4)
            values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                     i.cod_tra_padre,null,i.fecha,i.fec_valor,
                     i.monto ,i.mto_equ_local,i.estado,'Rev.Dev.Int.Susp.RES4 '||i.referencia,i.reversado,
                     i.cod_mod_padre,i.cod_mad_padre,user, v_hora,
                     v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                     i.cod_rubro,decode(i.tip_mov_rubro,'D','C','C','D', null) ,
                     i.referencia, i.cod_persona,
                     i.est_cuenta, i.protegido, i.cotizacion,
                     i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4);
        else
           insert into ge_movimientos
                  (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                   cod_tra_padre,cod_transaccion,fecha,fec_valor,
                   monto,mto_equ_local, estado,concepto,reversado,
                   cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                   nro_secuencia,nro_cuenta,cod_ofi_origen,
                   cod_rubro,tip_mov_rubro,
                   referencia, cod_persona,
                   est_cuenta,protegido,cotizacion,
                   nro_documento,nro_documento2,nro_documento3,nro_documento4)
          values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                   i.cod_tra_padre,null,i.fecha,i.fec_valor,
                   i.monto ,i.mto_equ_local,i.estado,'Rev.Dev.Int.Susp.RES4 '||i.referencia,i.reversado,
                   i.cod_mod_padre,i.cod_mad_padre,user, v_hora,
                   v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                   decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_int_sus_gs,v_cod_rubro_int_sus_usd),'C',
                   i.referencia, i.cod_persona,
                   i.est_cuenta, i.protegido, i.cotizacion,
                   i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4);

        end if;
      end loop;
    end if;

     if nvl(v_tie_sobregiro,'N') ='S'  then
         for i in c_movimientos_s loop
            v_lugar:='Reversando Sobregiro:'||i.nro_cuenta;
            v_fec_valor := i.fec_valor;
            v_nro_cuenta := i.nro_cuenta;
            v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
            insert into ge_movimientos
                        (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                         cod_tra_padre,cod_transaccion,fecha,fec_valor,
                         monto,mto_equ_local, estado,concepto,reversado,
                         cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                         nro_secuencia,nro_cuenta,cod_ofi_origen,
                         cod_rubro,tip_mov_rubro, referencia, cod_persona,
                         est_cuenta,protegido,cotizacion,
                         nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
                values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                         i.cod_tra_padre,i.cod_transaccion,i.fecha,i.fec_valor,
                         i.monto * -1,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local * -1),i.estado,'Rev.Int.Sobregiro RES4 '||i.referencia,i.reversado,
                         i.cod_mod_padre,i.cod_mad_padre,user, v_hora,
                         v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                         i.cod_rubro,i.tip_mov_rubro,
                         i.referencia, i.cod_persona,
                         i.est_cuenta, i.protegido, i.cotizacion,
                         i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
               v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
               insert into ge_movimientos
                        (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                         cod_tra_padre,cod_transaccion,fecha,fec_valor,
                         monto,mto_equ_local, estado,concepto,reversado,
                         cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                         nro_secuencia,nro_cuenta,cod_ofi_origen,
                         cod_rubro,tip_mov_rubro, referencia, cod_persona,
                         est_cuenta,protegido,cotizacion,
                         nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
                values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                         i.cod_tra_padre,NULL/*i.cod_transaccion*/,i.fecha,i.fec_valor,
                         i.monto ,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local),i.estado,'Rev.Int.Sobregiro RES4 '||i.referencia,i.reversado,
                         i.cod_mod_padre,i.cod_mad_padre,user, v_hora,
                         v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                         decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_sob_gs,v_cod_rubro_sob_usd),'C',
                         i.referencia, i.cod_persona,
                         i.est_cuenta, i.protegido, i.cotizacion,
                         i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
         end loop;
   end if;

else
   --Para las fechas anteriores
   --Obtiene la fecha actual del módulo
   begin
     select a.pri_dia_mes
      into v_fec_pri_habil
        from ge_calendarios a
           where cod_modulo = 6;  
   exception
     when no_data_found then 
       v_fec_pri_habil:=null;
   end;
   --Sino es primer dia habil se hace
   if v_fecha <> v_fec_pri_habil then
          v_hora_mov := fug_obt_hor_disponible(v_fec_actual, v_hora_mov, user, 'N');       
          v_nro_secuencia := 0;
          
           ---Obtenemos los datos,para generar movimientos reversión
           begin
              select decode(a.inv_ges_cobranza,0,'N','S'),decode(a.inv_interes,0,'N','S'),decode(a.inv_sobregiro,0,'N','S')
                     into v_tie_cobranza, v_tie_dev_suspenso, v_tie_sobregiro
                      from  PR_CTA_PRE_REF_RES4 a
                        where a.fec_proceso= trunc(v_fecha)
                             and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
                              and a.nro_sol_nueva= nvl(v_nro_sol_nueva,a.nro_sol_nueva);
           exception
             when no_data_found then
               v_tie_cobranza:='N';
               v_tie_dev_suspenso:='N';
               v_tie_sobregiro:='N';
             when others then
               v_tie_cobranza:='N';
               v_tie_dev_suspenso:='N';
               v_tie_sobregiro:='N';
           end;
          --
          if NVL(v_tie_cobranza,'N') ='S'  then
             for i in c_movimientos_his loop
                v_lugar:='Reversando Cobranza:'||i.nro_cuenta;
                v_fec_valor := i.fec_valor;
                v_nro_cuenta := i.nro_cuenta;
                v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
                insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
                    values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                             i.cod_tra_padre,i.cod_transaccion,v_fec_actual,v_fec_actual/*i.fec_valor*/,
                             i.monto * -1,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local * -1),i.estado,'Rev.Cobranza RES4 '||i.referencia,i.reversado,
                             i.cod_mod_padre,i.cod_mad_padre,user, v_hora_mov/*v_hora*/,
                             v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                             i.cod_rubro,i.tip_mov_rubro,
                             i.referencia, i.cod_persona,
                             i.est_cuenta, i.protegido, i.cotizacion,
                             i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
                   v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
                   insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
                    values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                             i.cod_tra_padre,NULL/*i.cod_transaccion*/,v_fec_actual/*i.fecha*/,v_fec_actual/*i.fec_valor*/,
                             i.monto ,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local),i.estado,'Rev.Cobranza RES4 '||i.referencia,i.reversado,
                             i.cod_mod_padre,i.cod_mad_padre,user, v_hora_mov/*v_hora*/,
                             v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                             decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_cob_gs,v_cod_rubro_cob_usd),'C',
                             i.referencia, i.cod_persona,
                             i.est_cuenta, i.protegido, i.cotizacion,
                             i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
             end loop;
           end if;
           if nvl(v_tie_dev_suspenso,'N') ='S'  then
              for i in c_mov_int_dev_his loop
                v_lugar:='Reversando Dev.Int.Susp.:'||i.nro_cuenta;
                v_fec_valor := i.fec_valor;
                v_nro_cuenta := i.nro_cuenta;
                v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                --v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                if i.tip_mov_rubro='C' then
                  insert into ge_movimientos
                              (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                               cod_tra_padre,cod_transaccion,fecha,fec_valor,
                               monto,mto_equ_local, estado,concepto,reversado,
                               cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                               nro_secuencia,nro_cuenta,cod_ofi_origen,
                               cod_rubro,tip_mov_rubro,
                               referencia, cod_persona,
                               est_cuenta,protegido,cotizacion,
                               nro_documento,nro_documento2,nro_documento3,nro_documento4)
                      values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                               i.cod_tra_padre,null,v_fec_actual/*i.fecha*/,v_fec_actual/*i.fec_valor*/,
                               i.monto ,i.mto_equ_local,i.estado,'Rev.Dev.Int.Susp.RES4 '||i.referencia,i.reversado,
                               i.cod_mod_padre,i.cod_mad_padre,user, v_hora_mov/*v_hora*/,
                               v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                               i.cod_rubro,decode(i.tip_mov_rubro,'D','C','C','D', null) ,
                               i.referencia, i.cod_persona,
                               i.est_cuenta, i.protegido, i.cotizacion,
                               i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4);
                  else
                     insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro,
                             referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                             i.cod_tra_padre,null,v_fec_actual/*i.fecha*/,v_fec_actual/*i.fec_valor*/,
                             i.monto ,i.mto_equ_local,i.estado,'Rev.Dev.Int.Susp.RES4 '||i.referencia,i.reversado,
                             i.cod_mod_padre,i.cod_mad_padre,user, v_hora_mov/*v_hora*/,
                             v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                             decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_int_sus_gs,v_cod_rubro_int_sus_usd),'C',
                             i.referencia, i.cod_persona,
                             i.est_cuenta, i.protegido, i.cotizacion,
                             i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4);

                  end if;
                end loop;
              end if;

              if nvl(v_tie_sobregiro,'N') ='S'  then
                   for i in c_movimientos_sob_his loop
                      v_lugar:='Reversando Sobregiro:'||i.nro_cuenta;
                      v_fec_valor := i.fec_valor;
                      v_nro_cuenta := i.nro_cuenta;
                      v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
                      insert into ge_movimientos
                                  (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                                   cod_tra_padre,cod_transaccion,fecha,fec_valor,
                                   monto,mto_equ_local, estado,concepto,reversado,
                                   cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                                   nro_secuencia,nro_cuenta,cod_ofi_origen,
                                   cod_rubro,tip_mov_rubro, referencia, cod_persona,
                                   est_cuenta,protegido,cotizacion,
                                   nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
                          values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                                   i.cod_tra_padre,i.cod_transaccion,v_fec_actual/*i.fecha*/,v_fec_actual/*i.fec_valor*/,
                                   i.monto * -1,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local * -1),i.estado,'Rev.Int.Sobregiro RES4 '||i.referencia,i.reversado,
                                   i.cod_mod_padre,i.cod_mad_padre,user, v_hora_mov/*v_hora*/,
                                   v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                                   i.cod_rubro,i.tip_mov_rubro,
                                   i.referencia, i.cod_persona,
                                   i.est_cuenta, i.protegido, i.cotizacion,
                                   i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
                         v_nro_secuencia := nvl(v_nro_secuencia,0)+1;
                         insert into ge_movimientos
                                  (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                                   cod_tra_padre,cod_transaccion,fecha,fec_valor,
                                   monto,mto_equ_local, estado,concepto,reversado,
                                   cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                                   nro_secuencia,nro_cuenta,cod_ofi_origen,
                                   cod_rubro,tip_mov_rubro, referencia, cod_persona,
                                   est_cuenta,protegido,cotizacion,
                                   nro_documento,nro_documento2,nro_documento3,nro_documento4,val_tasa)
                          values(i.cod_modulo,i.cod_modalidad,i.cod_oficina,i.cod_moneda,
                                   i.cod_tra_padre,NULL/*i.cod_transaccion*/,v_fec_actual/*i.fecha*/,v_fec_actual/*i.fec_valor*/,
                                   i.monto ,decode(i.cod_moneda, v_cod_mon_local, null,i.mto_equ_local),i.estado,'Rev.Int.Sobregiro RES4 '||i.referencia,i.reversado,
                                   i.cod_mod_padre,i.cod_mad_padre,user, v_hora_mov/*v_hora*/,
                                   v_nro_secuencia,i.nro_cuenta,i.cod_ofi_origen,
                                   decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_sob_gs,v_cod_rubro_sob_usd),'C',
                                   i.referencia, i.cod_persona,
                                   i.est_cuenta, i.protegido, i.cotizacion,
                                   i.nro_documento,i.nro_documento2,i.nro_documento3,i.nro_documento4,null);
                   end loop;
           end if;
   

   end if;

end if;




EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR. Rev.Canc.RE4.: '||v_lugar||'-'||SQLERRM);
END PRP_REV_GAN_RES4;
/

