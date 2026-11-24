CREATE OR REPLACE PROCEDURE IT.PRP_VAL_CAM_SOLICITUDES
 (P_CAMPANA   IN GE_SOLICITUDES.COD_CAMPANA%TYPE
 ,P_PERSONA   IN GE_SOLICITUDES.COD_PERSONA%TYPE
 ,P_MODULO    IN GE_MOVIMIENTOS.COD_MODULO%TYPE
 ,P_MODALIDAD IN GE_MOVIMIENTOS.COD_MODALIDAD%TYPE
 ,P_MONTO     IN GE_SOLICITUDES.MONTO%TYPE
 ,P_MONEDA    IN GE_SOLICITUDES.COD_MONEDA%TYPE
 ,P_PLAZO     IN GE_SOLICITUDES.PLZ_MESES%TYPE
 ,P_ESTADO    IN OUT VARCHAR2
 ,P_MOTIVO    IN OUT VARCHAR2
 )
 IS
   v_max_atraso      pr_cta_prestamos.max_atraso%type;
   v_ult_credito     pr_cta_prestamos.nro_solicitud%type := 0;
   v_can_creditos    number := 0;
   v_dia_atraso      pr_cta_prestamos.dia_atraso%type;
   v_cli_recurrente  varchar(1) := 'N';
   v_estado_pre      varchar(1) := '*';
   v_fec_cancelacion pr_cta_prestamos.fec_cancelacion%type;
   cursor c_solicitud is
   select p.nro_solicitud
   from   pr_cta_prestamos p,
          ge_cta_clientes  g,
          ge_est_cuentas   e
   where  p.nro_cuenta     = g.nro_cuenta
   and    g.cod_persona    = p_persona
   and    g.relacion       = 'P'
   and    p.cod_modulo     = e.cod_modulo
   and    p.cod_modalidad  = e.cod_modalidad
   and    p.estado         = e.estado
   and    e.activo         = v_estado_pre;

begin
   /*--------------------------------------------------------------------------------------------
   1) Dejar habilitar  la campaña CLIENTE EXCELENTE solamente a los clientes recurrentes
      cuyo  atraso máximo en el último crédito obtenido no haya sido mayor a 15 dias
      y en  el pago de la última cuota haya tenido un atraso máximo de 10  dias
   2) El cliente es considerado recurrente hasta 180 días luego de cancelado el último crédito.
   3) El producto "Préstamos" según las modalidades:  65, 66 y 67;
      en monedas Gs. y Usd. son los considerados para calificar al cliente como recurrente.
   --------------------------------------------------------------------------------------------*/

   /* -----------------     Validaciones agregadas el 17/jul/07      ------------------------
      Un cliente recurrente es aquel que tiene ya un credito con  la financiera,
      y en el caso de haber cancelado, se considera como recurrente
      si el ultimo credito fue hace como maximo 6 meses.
      Se debe considerar también los clientes con prestamos aprobados.
      Esta validación solamente debe realizar cuando se ingresa  por primera vez la solicitud.
   -----------------------------------------------------------------------------------------*/

   if p_campana in (4,5) then
     --verifica la modalidad es considerada para calificar al cliente como recurrente
     begin
       v_cli_recurrente := FUG_OBT_PARDINAMICO('MOD_CLI_RECURRENTE',P_MODULO,P_MODALIDAD,P_MONEDA,null);
     exception
       when others then
         v_cli_recurrente := 'N';
     end;
     --
     if v_cli_recurrente = 'S' then
       p_estado := 'S';
       --
       --Obtiene último crédito
       begin
         --Primero se busca si tiene creditos activos
         select count(*)
         into   v_can_creditos
         from   pr_cta_prestamos p,
                ge_cta_clientes  g,
                ge_est_cuentas   e
         where  p.nro_cuenta     = g.nro_cuenta
         and    g.cod_persona    = p_persona
         and    g.relacion       = 'P'
         and    p.cod_modulo     = e.cod_modulo
         and    p.cod_modalidad  = e.cod_modalidad
         and    p.estado         = e.estado
         and    e.activo         = 'S';
       exception
         when no_data_found then
            v_can_creditos := 0;
       end;
       --
       if nvl(v_can_creditos,0) = 0 then
         begin
           --Si no hay créditos activos se busca el último crédito cancelado
           select nvl(max(p.nro_solicitud),0)
           into   v_ult_credito
           from   pr_cta_prestamos p,
                  ge_cta_clientes  g
           where  p.nro_cuenta  = g.nro_cuenta
           and    g.cod_persona = p_persona
           and    g.relacion    = 'P'
           and    p.estado      = 'N';
         exception
           when no_data_found then
              p_estado := 'N';
              p_motivo := 'La persona no posee créditos que lo califiquen como CLIENTE EXCELENTE';
         end;
         --
         if v_ult_credito > 0 then
           v_estado_pre := 'N';
         else
           p_estado := 'N';
           p_motivo := 'La persona no posee créditos que lo califiquen como CLIENTE EXCELENTE';
         end if;
         --
       else
         v_estado_pre := 'S';
       end if;
       --
       --
       if v_estado_pre <> '*' then
         for i in c_solicitud loop
           --Si es préstamo cancelado solo se calcula en base al ultimo préstamo
           if (v_estado_pre = 'N' and i.nro_solicitud = v_ult_credito)
           or  v_estado_pre = 'S' then
           --Obtiene atraso máximo en el último crédito
           --y los días transcurridos luego de cancelado el último crédito.
             begin
               select nvl(p.max_atraso, p.fec_cancelacion - p.fec_vencimiento)
                    , p.fec_cancelacion
               into   v_max_atraso, v_fec_cancelacion
               from   pr_cta_prestamos p
               where  p.nro_solicitud = i.nro_solicitud;
             exception
               when no_data_found then
                  p_estado := 'N';
                  p_motivo := 'No se pudo obtener el ATRASO MAXIMO para el nro. solicitud '|| to_char(i.nro_solicitud);
             end;
             --
             --Verifica los días transcurridos luego de cancelado el último crédito.
             if (trunc(sysdate) - nvl(v_fec_cancelacion,sysdate)) > FUG_OBT_PARDINAMICO('DIA_CAN_ULT_CREDITO',P_MODULO,P_MODALIDAD,P_MONEDA,null) then
                p_estado := 'N';
                p_motivo := 'Los días transcurridos ('
                         || to_char(trunc(sysdate) - v_fec_cancelacion)
                         || ') luego de cancelado el último crédito es mayor a lo permitido ('
                         || to_char(FUG_OBT_PARDINAMICO('DIA_CAN_ULT_CREDITO',P_MODULO,P_MODALIDAD,P_MONEDA,null))
                         || '). No califica como CLIENTE EXCELENTE';
             else
               --Verifica el atraso máximo en el último crédito
               if nvl(v_max_atraso,0) > FUG_OBT_PARDINAMICO('CAM_MAX_ATRASO',P_MODULO,P_MODALIDAD,P_MONEDA,null) then
                  p_estado := 'N';
                  p_motivo := 'El atraso máximo ('
                           || to_char(v_max_atraso)
                           || ') del último crédito obtenido es mayor a lo permitido ('
                           || to_char(FUG_OBT_PARDINAMICO('CAM_MAX_ATRASO',P_MODULO,P_MODALIDAD,P_MONEDA,null))
                           || '). No califica como CLIENTE EXCELENTE';
               else
                  --Obtiene días atraso en el pago de la última cuota del último crédito
                  begin
                    select c.fec_ult_pago - c.fec_vencimiento
                    into   v_dia_atraso
                    from   pr_cta_prestamos p,
                           pr_cuotas        c
                    where  p.nro_cuenta    = c.nro_cuenta
                    and    p.nro_solicitud = i.nro_solicitud
                    and ( (p.can_cuotas    = c.nro_cuota
                            and p.estado = 'N')
                       or (p.can_cuo_pagadas = c.nro_cuota
                            and p.estado <> 'N') );
                  exception
                   when no_data_found then
                      p_estado := 'N';
                      p_motivo := 'No se pudo obtener los DIAS DE ATRASO para el nro. solicitud '|| to_char(i.nro_solicitud);
                  end;
                  --
                  --Verifica la cantidad de dias de atraso en el pago de la última cuota del último crédito
                  if nvl(v_dia_atraso,0) > FUG_OBT_PARDINAMICO('CAM_DIA_ATRASO',P_MODULO,P_MODALIDAD,P_MONEDA,null) then
                    p_estado := 'N';
                    p_motivo := 'Los días de atraso ('
                             || to_char(v_dia_atraso)
                             || ') en la última cuota del último crédito obtenido es mayor a lo permitido ('
                             || to_char(FUG_OBT_PARDINAMICO('CAM_DIA_ATRASO',P_MODULO,P_MODALIDAD,P_MONEDA,null))
                             || '). No califica como CLIENTE EXCELENTE';
                  end if;
               end if; --filtro por atraso máximo
             end if;   --filtro por dias transcurridos
           end if;     --filtro por estado del préstamo
           --
           --Si estado contiene error sale del ciclo
           if p_estado = 'N' then
              EXIT when p_estado = 'N';
           end if;
           --
         end loop;
       end if;         --filtro por solicitudes
     else
        p_estado := 'N';
        p_motivo := 'La modalidad ('
                 || to_char(P_MODALIDAD)
                 || ') no está asociada a la campaña CLIENTE EXCELENTE';
     end if;       --filtro por modalidad
   else
     p_estado := 'X';
     p_motivo := 'La campaña no es CLIENTE EXCELENTE';
   end if;         --filtro por campaña
end;
/

