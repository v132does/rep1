create or replace function it.fug_obt_est_mov_confirmado
  (p_monto                in ge_movimientos.monto%type,
   p_cod_moneda           in ge_movimientos.cod_moneda%type,
   p_cod_modulo           in ge_movimientos.cod_modulo%type,
   p_cod_modalidad        in ge_movimientos.cod_modalidad%type,
   p_cod_tra_padre        in ge_movimientos.cod_tra_padre%type,
   p_plataforma           in varchar2 default null, --ge_snp_transferencias.plataforma%type default null,
   p_nro_cuenta           in ge_movimientos.nro_cuenta%type        default null,
   p_cod_persona          in ge_movimientos.cod_persona%type       default null
   )  return varchar2 IS

   v_estado                  ge_movimientos.estado%type := 'N';
v_con_ope_mto_minimo      ge_par_dinamicos.val_parametro%type;

begin

 v_con_ope_mto_minimo := nvl(fug_obt_pardinamico('CON_OPE_MTO_MINIMO',p_cod_modulo,p_cod_modalidad,p_cod_moneda),0);

    ---Si es operación relacionada a SIPAP y se envia por plataforma X-Adapter el estado debe ser 'N'
    if p_cod_tra_padre = 303 and nvl(p_plataforma,'N') = 'X'  then
        v_estado := 'N';
  ---Si es operación relacionada a SIPAP y se envia por plataforma GUI el estado debe ser 'P'
    elsif p_cod_tra_padre = 303 and nvl(p_plataforma,'N') = 'G' then
        v_estado := 'P' ;

  ---Si la operación no esta relacionada a SIPAP se debe evaluar el monto parametrizado
  ---para dejar en estado P-Pendiente de Confirmación
    elsif p_cod_tra_padre <> 303 and nvl(p_plataforma,'N') not in ('X','G') then

      if nvl(p_monto,0) >= v_con_ope_mto_minimo then
        v_estado:= 'P';
      else
        v_estado := 'N';
      end if;
  end if;

  return v_estado;
exception
  when others then
   return v_estado;
end fug_obt_est_mov_confirmado;
/

