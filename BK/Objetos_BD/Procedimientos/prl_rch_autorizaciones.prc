create or replace procedure IT.PRL_RCH_AUTORIZACIONES is
   Cursor c_aut_pedidos is 
   Select p.fecha,
          p.hora, 
          p.cod_usuario, 
          g.nro_caja,  
          g.nro_documento4,           
          g.cod_mod_padre,  
          g.cod_mad_padre, 
          g.cod_tra_padre 
    from ge_aut_pedidos p, ge_movimientos g
      where p.respuesta = 'P'
         and p.estado = 'S'
         and trunc(p.fec_insercion)= trunc(sysdate) 
         and p.cod_usuario = g.cod_usuario
         and p.hora = g.hora
         and p.fecha = g.fecha
         and g.nro_secuencia = 1
         and (g.cod_modulo = 7 OR (g.cod_modulo = 9 AND g.cod_mod_padre = 7));
                 
  v_respuesta ge_aut_pedidos.respuesta%type;
  v_estado    ge_aut_pedidos.estado%type;
  v_cod_usu_autorizador ge_aut_pedidos.cod_usu_autorizador%type;
  ----
Procedure PR_ELI_AUTORIZACIONES is
-- Eliminacion de autorizaciones pendientes del dia
 begin
   delete from ge_aut_pedidos gaped
    where gaped.respuesta = 'P'
      and gaped.estado = 'S'
      and trunc(gaped.fec_insercion) = trunc(sysdate)
      and not exists
            (Select 1
             from ge_movimientos
            where fecha = pag_cal.fu_obt_fec_actual(1)
              and hora = gaped.hora
              and cod_usuario = gaped.cod_usuario
              and nro_secuencia = 1);
 end;
 --
procedure p_gen_transaccion
    (p_nro_caja       in number,
     p_hora           in varchar2,
     p_cod_transaccion in number)--245 246
     is

  v_monto         number := 0; -- monto
  v_efectivo      number := 0; -- importe en efectivo
  v_che_nue_bco   number := 0; -- importe en cheques
  v_che_otr_bco   number := 0; -- importe en otros cheques
  v_tot_debitos   number := 0;  -- total de debitos
  v_tot_creditos  number := 0;  -- total de creditos
  v_det_otr_bco   number := 0;  -- detalle de cheques
  v_cod_oficina   number(3);     -- Codigo de oficina
  v_estado        number(1);     -- estado de la caja
  v_fec_caja      date;          -- fecha de la caja
  v_sal_actual    number(18,2);  -- saldo actual de la caja en efectivo
  v_sal_cheques   number(18,2);  -- saldo actual de la caja en cheques

  cursor cj_movs is
    select cod_moneda, monto, tipo, tip_monto, tot_detallado,
           nro_doc_referencia, rowid,
           nro_documento, cod_mod_padre, cod_usuario
      from cj_movimientos
     where nro_caja = to_number(p_nro_caja)
       and hora = p_hora
       and cod_tra_padre = to_number(p_cod_transaccion)
       and estado = 'N'; -- normal

procedure lp_rev_transaccion(p_rowid in varchar2,
p_cod_moneda in varchar2,
p_monto in number,
p_tipo in varchar2,
p_tip_monto in varchar2,
p_nro_doc_referencia in number,
p_nro_documento in number,
p_cod_mod_padre in number) is

begin
   -- inicializo los datos
   v_efectivo      := 0;
   v_che_nue_bco   := 0;
   v_che_otr_bco   := 0;
   v_tot_debitos   := 0;
   v_tot_creditos  := 0;
   v_det_otr_bco   := 0;
   v_monto         := 0;
   -- Actualizo el control de caja
   if p_tipo = 'D' then  -- es un debito
      v_monto := p_monto * -1;
      if p_tip_monto = 'E' then
         v_tot_debitos := v_monto;
      end if;
   elsif p_tipo = 'C' then  -- es credito
      v_monto := p_monto;
      if p_tip_monto = 'E' then
         v_tot_creditos := v_monto * -1;
      end if;
   end if;
   if p_tip_monto = 'E' then
      v_efectivo := v_monto;
   elsif p_tip_monto = 'C' then
      v_che_nue_bco := v_monto;
   end if;
   -- actualizo los datos del control
    update cj_controles
      set sal_actual = nvl(sal_actual,0) + nvl(v_efectivo,0),
          tot_debitos = nvl(tot_debitos,0) + nvl(v_tot_debitos,0),
          tot_creditos = nvl(tot_creditos,0) + nvl(v_tot_creditos,0),
          can_debitos = nvl(can_debitos,0) - decode(v_tot_debitos,0,0,1),
          can_creditos  = nvl(can_creditos,0) - decode(v_tot_creditos,0,0,1),
          tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_che_nue_bco,0),
          sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_che_otr_bco,0),
          tot_che_otr_bco = nvl(tot_che_otr_bco,0) + decode(p_tipo,'D',nvl(v_che_otr_bco,0),0), -- SOLO SI FUE UN INGRESO
          det_che_otr_bco = nvl(det_che_otr_bco,0) - nvl(v_det_otr_bco,0),
          estado = 1 -- abierto
    where nro_caja = to_number(p_nro_caja)
      and cod_moneda = p_cod_moneda
      and fecha = v_fec_caja;
    if sql%notfound then
       Raise_application_error(-20000,'No existe Control de Caja');
    end if;
    update cj_movimientos
       set estado = 'R' -- reversado
     where rowid = p_rowid;
end;

begin
  for cj in cj_movs loop
     -- Obtengo los datos de la caja x moneda local------------------
     prj_obt_datos_caja(p_nro_caja,
                        cj.cod_moneda,
                        v_cod_oficina,
                        v_fec_caja,
                        v_estado,
                        v_sal_actual,
                        v_sal_cheques);

    lp_rev_transaccion(cj.rowid,cj.cod_moneda, cj.monto,
                       cj.tipo, cj.tip_monto,
                       cj.nro_doc_referencia,cj.nro_documento,
                       cj.cod_mod_padre);
  end loop;
exception
  when  others then
    If sqlcode <= -20000 then
       raise;
    Else
      Raise_application_error(-20004, 'Actualiza Controles Caja' ||sqlerrm);
    End If;
end;
----
begin
  v_respuesta := 'R';
  v_estado    := 'A'; -- anulado
  v_cod_usu_autorizador := user;

  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
  PR_ELI_AUTORIZACIONES;
  For r1 in c_aut_pedidos Loop
   
    if r1.cod_mod_padre = 7 then
      --Si viene de caja se reversan los controles y movimientos
      if r1.nro_caja is not null then
        p_gen_transaccion(r1.nro_caja,r1.hora,r1.nro_documento4);
      end if;
      --Reversar los movimientos de cambios
      prg_rev_operacion(r1.fecha,
                       r1.hora,
                       r1.cod_usuario,
                       7,
                       r1.cod_mad_padre,
                       r1.cod_tra_padre,--indica la operacion
                       user, ---cod_usu_reversion
                       fug_ini_hora(sysdate,'hh24:mi:ss'),
                       'N'); --Es nocturno.

      if pag_cta.fu_obt_cod_error() <> 0 then
         raise_application_error(-20002, pag_cta.fu_obt_cod_error()||' - '||pag_cta.fu_obt_msj_error());
      end if;     
    End if;  
        --- Actualiza el estado del pedido de Autorizacion.    
        Update ge_aut_pedidos
           set respuesta = v_respuesta,
               estado = v_estado,
               cod_usu_autorizador = v_cod_usu_autorizador
         where cod_usuario = r1.cod_usuario
           and fecha = r1.fecha
           and hora = r1.hora
           and respuesta = 'P'
           and estado = 'S';    
  End Loop;
end PRL_RCH_AUTORIZACIONES;

