create or replace function it.fue_val_eje_objeto(p_objeto  in varchar2,
                                              p_accion  in varchar2,
                                              p_mensaje in out varchar2)
   return varchar2 is
   Result varchar2(1) := 'S';
begin
   p_mensaje := null;
   if p_objeto in ('PROCEDIMIENTO', 'PAQUETE', 'FUNCION', 'PROGRAMA') and
      nvl(p_accion, 'X') <> 'EJECUTA' then
      p_mensaje := 'Para el objeto ' || p_objeto ||
                   ' solo puede marcar EJECUTA';
      Result    := 'N';
   elsif p_objeto = 'TABLA' and
         nvl(p_accion, 'X') not in
         ('INSERTA', 'ELIMINA', 'MODIFICA', 'CONSULTA') then
      p_mensaje := 'Para el objeto ' || p_objeto ||
                   ' solo puede marcar INSERTA o ELIMINA o MODIFICA o CONSULTA';
      Result    := 'N';
   elsif p_objeto in ('VISTA', 'SECUENCIA') and
         nvl(p_accion, 'X') <> 'CONSULTA' then
      p_mensaje := 'Para el objeto ' || p_objeto ||
                   ' solo puede marcar CONSULTA';
      Result    := 'N';
   elsif p_objeto = 'PARAMETRO' and nvl(p_accion, 'X') <> 'OTRO' then
      p_mensaje := 'Para el objeto ' || p_objeto ||
                   ' solo puede marcar OTRO';
      Result    := 'N';
   else
      Result := 'S';
   end if;
   return Result;
end;
/

