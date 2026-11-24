CREATE OR REPLACE TRIGGER IT.TB_CC_CHE_REMITIDOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_CHE_REMITIDOS
 FOR EACH ROW
declare
 v_cambia varchar2(1) := 'N';
 v_existe varchar2(1) := 'N';
 v_vexiste  varchar2(1);
 v_cod_custodia cc_che_custodias.cod_che_custodia%type;
begin
  --Control de ingreso solo para los Bancos Activos
  if inserting then
     begin
       select 'S'
         into v_existe
         from ge_bancos b
        where b.cod_banco = :new.cod_banco
          and b.estado = 'A'
          and b.ubicacion = 'L';
     exception
        when others then
            RAISE_APPLICATION_ERROR( -20000,'Existe un Código de Banco no válido :'
            ||to_char(:new.cod_banco)||' con el Nro de cheque :'||to_char(:new.nro_cheque));
     end;
  end if;
  if updating and (:new.cod_banco <> :old.cod_banco
                   or :new.nro_cheque <> :old.nro_cheque
                   or :new.monto <> :old.monto) then
     v_cambia := 'S';
  end if;
  if (updating and v_cambia = 'S') or deleting then
     update cc_che_enviados
        set estado = 'I'  -- ingresado
      where cod_banco = :old.cod_banco
        and nro_cheque = :old.nro_cheque
        and monto = :old.monto
        and estado = 'E';
     update ge_che_custodias
        set estado = 'C'  -- en custodia
      where cod_banco = :old.cod_banco
        and nro_cheque = :old.nro_cheque
        and monto = :old.monto
        and estado = 'A';
  end if;
  If (updating and v_cambia = 'S') or inserting then
     if nvl(:new.tip_dato, 1) = 1 then    
       update cc_che_enviados
          set estado = 'E',  -- enviado a camara
              fec_envio = :new.fecha
        where cod_banco = :new.cod_banco
          and nro_cheque = :new.nro_cheque
          and monto = :new.monto
          and estado = 'I'
          and cod_cau_devolucion is null;
     else
       update cc_che_enviados
          set estado = 'E',  -- enviado a camara
              com_directa = 'S',
              fec_envio = :new.fecha
        where cod_banco = :new.cod_banco
          and nro_cheque = :new.nro_cheque
          and monto = :new.monto
          and cod_moneda = 'USD'
          and fec_envio is null;
     end if;       
       update ge_che_custodias
          set estado = 'A',  -- enviado a camara
              cod_cau_devolucion = null
        where cod_banco = :new.cod_banco
          and nro_cheque = :new.nro_cheque
          and monto = :new.monto
          and estado in ('C','B');
  end if;
  /* CRO-JM-08/2014 buscamos el cheque si existe en la tabla de cc_che_custodias_det
** pero solo si es cargos otros bancos:
*/
  if updating and :new.cod_cau_devolucion is not null and (:new.cod_banco <> 7) then
      begin
        begin
          select 'S', a.cod_che_custodia -- buscamos si existe este cheque en custodias:
            into v_vexiste, v_cod_custodia
            from cc_che_custodias a, cc_che_custodias_det b
           where a.cod_che_custodia = b.cod_che_custodia
             and b.nro_documento = :new.nro_cheque
             and b.nro_cta_debito = :new.nro_cuenta
             and b.cod_emisor = :new.cod_banco
             and a.cod_oficina = :new.cod_oficina;
        exception
          when others then
            v_vexiste := 'N';
        end;
           if v_vexiste = 'S' then
             update cc_che_custodias_det a
             set a.estado = 'B' -- seteamos como devuelto de Cámara/rechazado:
             where a.cod_che_custodia = v_cod_custodia
             and   a.nro_cta_debito = :new.nro_cuenta
             and   a.nro_documento = :new.nro_cheque
             and   a.cod_emisor = :new.cod_banco; 
           end if;
      end;
   end if;
end;
/

