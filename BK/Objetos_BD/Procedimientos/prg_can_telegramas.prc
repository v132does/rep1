CREATE OR REPLACE PROCEDURE IT.PRG_CAN_TELEGRAMAS
 IS
cursor telegramas is
  select ref_cuentas,cod_persona,cod_causa,estado,fec_generacion, rowid fila
    from ge_telegramas
   where estado <> 'N'   --Cancelado
     and cod_causa in (101,116)
     and fec_entrega is not null;
 v_nro_cuenta varchar(100);
/* Actualizar el estado del telegrama */
PROCEDURE LP_ACT_EST_TELEGRAMA
 (fila in varchar2
 )
 IS
begin
   update ge_telegramas
      set estado = 'N'
    where rowid = fila;
exception
  when others then
    raise_application_error(-20000,'Actualizar estado del telegrama');
end;
begin
  for i in telegramas loop
    If i.cod_causa = 101 then
        --Motivo 1.  CAUSAL 101 :Saldo cero y sin movimientos por 90 dias
        begin
          select cc.nro_cuenta
            into v_nro_cuenta
            from cc_cta_corrientes cc
           where cc.nro_cuenta = i.ref_cuentas
             and nvl(cc.sal_total,0) = 0
             and nvl(cc.sal_bloqueado,0) = 0
             and nvl(cc.sal_retenido,0)= 0
             and cc.estado = 'I';
        exception  -- si la cuenta ya no esta inactiva y con saldo 0, se cancela el telegrama
          when no_data_found then
            LP_ACT_EST_TELEGRAMA(i.fila);
        end;
    elsif i.cod_causa = 116 then
        -- Motivo 2.  CAUSAL 116 :Sobregiro de 30 dias
        begin
          select cc.nro_cuenta
            into v_nro_cuenta
            from cc_cta_corrientes cc,
                 cc_sobregiros_res sob
           where cc.nro_cuenta = i.ref_cuentas
             and cc.estado not in ('X','A','C','P')
             and cc.nro_cuenta = sob.nro_cuenta
             and sob.can_dias >= 30;        
        exception
          when no_data_found then
            LP_ACT_EST_TELEGRAMA(i.fila);
        end;
    End if;
  end loop;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Cancelación de telegramas '||sqlerrm);
    End if;
end;
/

