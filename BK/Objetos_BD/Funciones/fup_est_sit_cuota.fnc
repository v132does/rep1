create or replace function it.fup_est_sit_cuota(
   p_fec_ult_pago date,
   p_nro_cuenta   pr_cta_prestamos.nro_cuenta%Type,
   p_nro_cuota    pr_cuotas.nro_cuota%type,
   p_atraso       number,
   p_estado       pr_cuotas.estado%type)
return Char is
   v_categoria varchar(35);
   v_cod_modalidad ge_modalidades.cod_modalidad%type;
   v_nro_cuota     pr_cuotas.nro_cuota%type;
   v_fec_ult_pago  date;
begin
   begin
      select cod_modalidad
        into v_cod_modalidad
        from ge_cuentas
       where nro_cuenta = p_nro_cuenta;
   exception
      when others then
         return null;
   end;
   ---
   v_nro_cuota := p_nro_cuota;
   If p_fec_ult_pago is null then
        Select max(fecha)
          into v_fec_ult_pago
          from pr_cobros
         where nro_cuenta = p_nro_cuenta;
        Select max(nro_cuota)
          into v_nro_cuota
          from pr_cobros
         where nro_cuenta = p_nro_cuenta
           and fecha = v_fec_ult_pago;         
   end if;    
   If v_fec_ult_pago is not null then
      begin
        Select decode(estado,'C',1,'A',1,'V',2,'G',3,'M',4,5)
          into v_categoria
          from pr_cobros
         where nro_cuenta = p_nro_cuenta
           and nro_cuota  = v_nro_cuota
           and fecha = v_fec_ult_pago;
      exception
          when others then
             v_categoria := null;
      end;
   end if;
   if v_categoria is not null then
      return v_categoria;
   else
      IF v_cod_modalidad in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
        FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6)) then
         if p_atraso < 31 THEN
            IF v_cod_modalidad = FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6) then
               return '1';
            else
               return '2';
            end if;
         elsif p_atraso > 30 and p_atraso < 91 then
            return '2';
         elsif p_atraso > 90 and p_atraso < 181 then
            return '3';
         elsif p_atraso > 180 and p_estado != 'I' then
            return '4';
         elsif p_estado = 'I' Then
            return '5';
         end if;
      ELSE -- otras modalidades
         IF p_atraso < 61 THEN
            return '1';
         ELSIF p_atraso > 60 and p_atraso < 91 THEN
            return '2';
         ELSIF p_atraso > 90 and p_atraso < 181 THEN
            return '3';
         elsif p_atraso > 180 and p_estado != 'I' then
            return '4';
         elsif p_estado = 'I' Then
            return '5';
         END IF;
      END IF; -- modalidades
   end if;
   return '1';
end;
/

