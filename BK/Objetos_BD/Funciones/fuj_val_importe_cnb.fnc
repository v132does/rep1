create or replace function it.FUJ_VAL_IMPORTE_CNB
   (p_tipo       in varchar2,  -- Tipo de operación: D-débito o C-crédito
    p_tip_monto  in varchar2,  -- tipo de monto E-efectivo, C-Cheq.ntro.bco O-Cheq.otr.bcos
    p_cod_moneda in varchar2,  -- moneda de la operacion
    p_importe    in number,    -- importe de la operacion
    p_cod_tra_padre in number default null,
    p_nro_cuenta in varchar2 default null,
    p_cod_usuario in varchar2) -- Transaccion padre
  return varchar2 is
  --
  v_cod_usuario       ba_usuarios.cod_usuario%type := nvl(p_cod_usuario,user); -- usuario
  v_mto_max_permitido ah_cta_vistas.sal_total%type;  -- monto máximo permitido
  v_mto_min_cuenta    ah_cta_vistas.sal_total%type := 0;
  v_exo_mto_minimo    varchar2(1);
  v_res_saldo         ah_cta_vistas.sal_total%type := 0;
  v_cod_seg_funcionario ge_seg_clientes.cod_seg_cliente%type := fug_obt_pardinamico('GEN_COD_SEG_FUNCIONARIO');
  -- mensaje de salida ---
  v_salida varchar2(200)  := NULL;
begin
  IF p_nro_cuenta IS NOT NULL THEN
     pag_cta.PR_OBT_CUENTA(P_NRO_CUENTA);
  END IF;
  if p_importe is null then
     v_salida := 'ERROR: Ingresar importe';
  elsif p_importe < 0 then
     v_salida := 'ERROR: Importe no puede ser negativo';
  elsif p_cod_moneda = 'GS'  and  p_importe <> trunc(p_importe) then
     v_salida := 'ERROR. Importe no debe tener decimales';
  else
    if p_tip_monto = 'E' then -- si es efectivo
        if p_tipo = 'C' then -- egreso a la caja, verifico alzada del usuario
           -- obtengo la máxima alzada para este cajero
           v_mto_max_permitido := fuj_obt_max_limite(v_cod_usuario, p_cod_moneda, p_cod_tra_padre);
           IF pag_cta.g_ctas.cod_modulo = 3 THEN
              v_exo_mto_minimo := fug_obt_paradicional(p_nro_cuenta, 'EXO_MTO_MINIMO');
              v_mto_min_cuenta := fug_obt_pardinamico('AHO_MTO_MIN_CUENTA', pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad, p_cod_moneda, null);
              v_res_saldo := pag_cta.G_CTAS.SAL_DISPONIBLE - p_importe;
           END IF;
           if nvl(v_mto_max_permitido,0) < p_importe or (v_mto_min_cuenta > v_res_saldo)  then
             if (nvl(pag_cta.G_CTAS.cod_seg_cliente,0) <> v_cod_seg_funcionario) and (nvl(v_exo_mto_minimo,'N') <> 'S') then
              declare
                v_fila varchar2(100);
                v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(9);
              begin
                 select rowid
                   into v_fila
                   from ge_autorizaciones a
                  where a.cod_usu_utilizador is null
                    and a.fec_utilizacion is null
                    and a.cod_moneda = p_cod_moneda
                    and a.fecha = v_fec_actual
                    and a.valor = p_importe
                    and a.cod_mod_padre = 9
                    and a.cod_usuario = user
                    and nvl(a.nro_cuenta,'x') = nvl(p_nro_cuenta,nvl(a.nro_cuenta,'x'))
                    and (case when a.cod_tra_padre = 241 then 245
                              when a.cod_tra_padre = 242 then 245
                              when a.cod_tra_padre = 246 then 245
                              else a.cod_tra_padre end) = p_cod_tra_padre
                    and rownum = 1; --para que tome una, x si hay varias autorizaciones
                 -- las autorizaciones de operaciones de cambios son generales
                 -- actualizo la autorizacion como utilizada
                 update ge_autorizaciones
                    set cod_usu_utilizador = user,
                        fec_utilizacion = v_fec_actual,
                        hor_utilizacion = to_char(sysdate,'HH24:MI:SS')
                  where rowid = v_fila;
                 if sql%notfound then
                    raise no_data_found;
                 end if;
              exception
                 when no_data_found then
                    if p_nro_cuenta is null then
                       v_salida := 'Cajero no habilitado para operar con este Monto en '||p_cod_moneda||'. Solicite Autorización';
                    else
                      if nvl(v_mto_max_permitido,0) < p_importe then
                          v_salida := 'Cajero no habilitado para operar con este Monto en '||p_cod_moneda||'. Solicite Autorización';
                      elsif  v_mto_min_cuenta > v_res_saldo then
                          if v_mto_min_cuenta <= 0 then --no existe límite mínimo a mantener, simplemente no tiene saldo
                             v_salida := 'Saldo Insuficiente en la Cuenta '||p_nro_cuenta||' para realizar la operación';
                          else
                             v_salida := 'El saldo resultante será inferior al mínimo exigido a mantener en la Cuenta '||p_nro_cuenta|| '. Solicite Autorización';
                          end if;
                      end if;
                    end if;
                 when others then
                    v_salida := 'Al leer Autorizacion '||sqlerrm;
              end;
             end if;
           end if;
          else ----agregado 31/05/2021
               if p_tipo = 'D' then -- egreso a la caja, verifico alzada del usuario
                   -- obtengo la máxima alzada para este cajero
                   v_mto_max_permitido := fuj_obt_max_limite(v_cod_usuario, p_cod_moneda, p_cod_tra_padre);
                   if nvl(v_mto_max_permitido,0) < NVL(p_importe,0) and NVL(p_importe,0) <> 0 then
                      v_salida := 'Cajero no habilitado para operar con este Monto en '||p_cod_moneda||'. Solicite Autorización.'||p_tip_monto||p_importe;
                   end if;
               end if;
          end if;
    end if;
   end if;
  -- Retorno el mensaje de error
  return(v_salida);
exception
   when others then
      return ('ERROR: en FUJ_VAL_OPERACION ' ||sqlerrm);
end FUJ_VAL_IMPORTE_CNB;
/

