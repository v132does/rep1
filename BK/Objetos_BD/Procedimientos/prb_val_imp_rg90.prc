create or replace procedure it.PRB_VAL_IMP_RG90 is
  v_error               varchar2(4000);
  v_tipo_identificador  varchar2(3);
  v_nro_comprobante     varchar2(20);
  V_MONTO_GRAVADO_10    number;
  V_MONTO_GRAVADO_5     number;
  V_MONTO_EXENTO        number;
  V_MONTO_TOTAL         number;
  v_condicion           varchar2(1);
  v_moneda_extranjera   varchar2(1);
  v_imputa_iva          varchar2(1);
  v_no_imputa           varchar2(1);
  v_nro_comprobante_ref varchar2(20);
  v_timbrado            varchar2(10);
  -- cursor para generar detalle
  cursor detalle is
      Select d.rowid, d.* From CB_RG_90_IMP D
      order  by TIPO_REGISTRO, fecha_emision, d.nro_comprobante;
BEGIN
  for j in detalle loop
   v_error:= null;
   --valida tipo_registro
   if j.tipo_registro is null then
       v_error:=  nvl(v_error,'')||'- No se enontró Tipo de Registro, favor verifique.';
   else
     --venta tipo registro 1
     if j.tipo_registro = 1 then
       if j.cod_tip_documento is null then
          v_error:=  nvl(v_error,'')||'- No se enontró Tipo de Identificacion.';
       else
         v_tipo_identificador :=j.cod_tip_documento;
       end if;
       --valida nro_identificador
       if j.NRO_IDENTIFICADOR is null then
          v_error:=  nvl(v_error,'')||'- No se enontró Número de Documento.';
       end if;
       --validar razon social
       if j.RAZ_SOCIAL is null and j.NRO_IDENTIFICADOR not in(11,12,15) then
          v_error:=  nvl(v_error,'')||'- No se enontró Razón Social.';
       end if;
       --validar cod_tipo_comprobante
       if j.COD_TIPO_COMPROBANTE is null  then
          v_error:=  nvl(v_error,'')||'- No se enontró Código de Tipo de Comprobante.';
       end if;
       --validar fecha
       if j.fecha_emision is null  then
          v_error:=  nvl(v_error,'')||'- No se enontró fecha_emisionde Comprobante.';
       elsif j.fecha_emision < to_date('01/01/2021','dd/mm/yyyy') and j.CONDICION <> '1' then
          v_error:=  nvl(v_error,'')||'- fecha_emisionincorrecta, menor a 01/01/2021';
       end if;
       --validacion de timbrado
       if j.nro_timbrado is null then
          v_error:=  nvl(v_error,'')||'- No se encontro Timbrado';
       else
          v_timbrado := j.nro_timbrado;
       end if;
       --validacion de nro_comprobante
       if j.nro_comprobante is null then
          if  j.COD_TIPO_COMPROBANTE not in ('112','106') then
              v_error:=  nvl(v_error,'')||'- Numero de comprobante no puede ser vacío';
          end if;
       else
         begin
           Select to_number(replace(j.nro_comprobante,'-','0')) nro_comprobante
           into   v_nro_comprobante
           from   dual
           where  j.nro_comprobante like '___-___-_______'
           and    to_number(substr(j.nro_comprobante,1,3))>0
           and    to_number(substr(j.nro_comprobante,5,3))>0
           and    to_number(substr(j.nro_comprobante,9,7))>0;
         exception
           when others then
             v_error:=  nvl(v_error,'')||'- Número de comprobante con formato inválido.';
         end;
     end if;
     --monto_Gravado_10
     if nvl(j.MONTO_GRAVADO_10,0) <0 then
        v_error:=  nvl(v_error,'')||'-Monto Gravada al 10% es negativo.';
     else
        V_MONTO_GRAVADO_10 := nvl(ROUND(j.MONTO_GRAVADO_10,0),0);
     end if;
     --monto_Gravado_5
     if nvl(j.MONTO_GRAVADO_5,0) <0 then
        v_error:=  nvl(v_error,'')||'-Monto Gravada al 5% es negativo.';
     else
        V_MONTO_GRAVADO_5 := nvl(ROUND(j.MONTO_GRAVADO_5,0),0);
     end if;
     --monto_Exento
     if nvl(J.MONTO_EXENTO,0) <0 then
        v_error:=  nvl(v_error,'')||'-Monto Exnto es negativo.';
     else
        V_MONTO_EXENTO := nvl(ROUND(J.MONTO_EXENTO,0),0);
     end if;
     --MONTO_TOTAL
     if nvl(J.MONTO_TOTAL,0) <0 then
        v_error:=  nvl(v_error,'')||'-Monto total es negativo.';
     else
        V_MONTO_TOTAL := nvl(ROUND(J.MONTO_TOTAL,0),0);
     end if;
     --condicion venta
     if j.condicion is null and j.COD_TIPO_COMPROBANTE = 109 then
         v_error:=  nvl(v_error,'')||'- Es necesario definir una condicion de venta';
     else
         v_condicion := nvl(j.condicion,1);
     end if;
     --moneda extranjera
     v_moneda_extranjera := nvl(j.MONEDA_EXTRANJERA,'N');
     --imputa iva
     if V_MONTO_GRAVADO_10 + V_MONTO_GRAVADO_5 + V_MONTO_EXENTO > 0 then
      v_imputa_iva := 'S';
     else
       v_imputa_iva := 'N';
     end if;
     --Notas de creditos
     if j.COD_TIPO_COMPROBANTE in (110,111) then--si es NC
        --nro_comprobante_asociado
        if j.FACTURA_ASOCIADA is null then
           v_error:=  nvl(v_error,'')||'- Es necesario definir un numero de comprobante asociado a la Nota de Crédito';
        else
         begin
           Select to_number(replace(j.FACTURA_ASOCIADA,'-','0')) nro_comprobante
           into   v_nro_comprobante_ref
           from   dual
           where  j.FACTURA_ASOCIADA like '___-___-_______'
           and    to_number(substr(j.FACTURA_ASOCIADA,1,3))>0
           and    to_number(substr(j.FACTURA_ASOCIADA,5,3))>0
           and    to_number(substr(j.FACTURA_ASOCIADA,9,7))>0;
         exception
           when others then
             v_error:=  nvl(v_error,'')||'- Número de comprobante asociado con formato inválido.';
         end;
        end if;
        --nro_timbrado_asociado
        if j.TIMBRADO_ASOCIADO is null then
           v_error:=  nvl(v_error,'')||'- Es necesario definir un numero de timbrado asociado a la Nota de Crédito';
        end if;
     end if;
    --------------------------------------FIN VENTAS---------------------------------------------
   elsif j.tipo_registro = 2 then --Compras--2
       if j.cod_tip_documento is null then
          v_error:=  nvl(v_error,'')||'- No se enontró Tipo de Identificacion.';
       elsif j.COD_TIPO_COMPROBANTE not in (101,107) then
         v_tipo_identificador := '11';
       else
         v_tipo_identificador := j.cod_tip_documento;
       end if;
       --valida nro_identificador--3
       if j.NRO_IDENTIFICADOR is null then
          v_error:=  nvl(v_error,'')||'- No se enontró Número de Documento.';
       end if;
       --validar razon social--4
       if j.RAZ_SOCIAL is null and j.NRO_IDENTIFICADOR not in(11,12) then
          v_error:=  nvl(v_error,'')||'- No se enontró Razón Social.';
       end if;
       --validar cod_tipo_comprobante--5
       if j.COD_TIPO_COMPROBANTE is null  then
          v_error:=  nvl(v_error,'')||'- No se enontró Código de Tipo de Comprobante.';
       end if;
       --validar fecha--6
       if j.fecha_emision is null  then
          v_error:=  nvl(v_error,'')||'- No se enontró fecha_emisionde Comprobante.';
       elsif j.fecha_emision < to_date('01/01/2021','dd/mm/yyyy') and j.CONDICION <> '1' then
          v_error:=  nvl(v_error,'')||'- Fecha_emision incorrecta, menor a 01/01/2021';
        end if;
       --validacion de timbrado--7
       if j.nro_timbrado is null then
         if j.cod_tipo_comprobante = 107 then
            v_timbrado := 0;
         else
            v_error:=  nvl(v_error,'')||'- No se encontró Timbrado';
         end if;
       else
          v_timbrado := j.nro_timbrado;
       end if;
       --validacion de nro_comprobante--8
       if j.nro_comprobante is null then
          if  j.COD_TIPO_COMPROBANTE not in ('102','106','107') then
              v_error:=  nvl(v_error,'')||'- Numero de comprobante no puede ser vacío';
          end if;
       else
         begin
           Select to_number(replace(j.nro_comprobante,'-','0')) nro_comprobante
           into   v_nro_comprobante
           from   dual
           where  j.nro_comprobante like '___-___-_______'
           and    to_number(substr(j.nro_comprobante,1,3))>0
           and    to_number(substr(j.nro_comprobante,5,3))>0
           and    to_number(substr(j.nro_comprobante,9,7))>0;
         exception
           when others then
             v_error:=  nvl(v_error,'')||'- Número de comprobante con formato inválido.';
         end;
     end if;
     --monto_Gravado_10--9
     if nvl(j.MONTO_GRAVADO_10,0) <0 then
         v_error:=  nvl(v_error,'')||'- Monto Gravada al 10% es negativo.';
     else
       if j.COD_TIPO_COMPROBANTE not in ('101','104','112')  then
         V_MONTO_GRAVADO_10 := nvl(ROUND(j.MONTO_GRAVADO_10,0),0);
       else
         V_MONTO_GRAVADO_10 := 0;
       end if;
     end if;
     --monto_Gravado_5--10
     if nvl(j.MONTO_GRAVADO_5,0) <0 then
         v_error:=  nvl(v_error,'')||'- Monto Gravada al 5% es negativo.';
     else
       if j.COD_TIPO_COMPROBANTE not in ('101','104','112')  then
         V_MONTO_GRAVADO_5 := nvl(ROUND(j.MONTO_GRAVADO_5,0),0);
       else
         V_MONTO_GRAVADO_5 := 0;
       end if;
     end if;
     --monto_Exento--11
     if nvl(J.MONTO_EXENTO,0) <0 then
        v_error:=  nvl(v_error,'')||'- Monto Exnto es negativo.';
     else
       if j.COD_TIPO_COMPROBANTE not in ('101','104','112')  then
         V_MONTO_EXENTO := nvl(ROUND(j.MONTO_EXENTO,0),0);
       else
         V_MONTO_EXENTO := 0;
       end if;
     end if;
     --MONTO_TOTAL--12
     if nvl(J.MONTO_TOTAL,0) <0 then
        v_error:=  nvl(v_error,'')||'- Monto total es negativo.';
     else
        V_MONTO_TOTAL := nvl(ROUND(J.MONTO_TOTAL,0),0);
     end if;
     --condicion venta
     if j.condicion is null and j.COD_TIPO_COMPROBANTE = 109 then
         v_error:=  nvl(v_error,'')||'- Es necesario definir una condicion de venta';
     else
         v_condicion := nvl(j.condicion,1);
     end if;
     --moneda extranjera
     v_moneda_extranjera := nvl(j.MONEDA_EXTRANJERA,'N');---calcular este valor
     --imputa iva
     if V_MONTO_GRAVADO_10 + V_MONTO_GRAVADO_5 + V_MONTO_EXENTO > 0 then
       v_imputa_iva := 'S';
       v_no_imputa  :='S';
     else
       v_imputa_iva := 'N';
       v_no_imputa  := 'N';
     end if;
     --
     --Notas de creditos
     if j.COD_TIPO_COMPROBANTE in (110,111) then--si es NC
        --nro_comprobante_asociado
        if j.FACTURA_ASOCIADA is null then
           v_error:=  nvl(v_error,'')||'- Es necesario definir un numero de comprobante asociado a la Nota de Crédito';
        else
            begin
                Select to_number(replace(j.FACTURA_ASOCIADA,'-','0')) nro_comprobante
                into   v_nro_comprobante_ref
                from   dual
                where  j.FACTURA_ASOCIADA like '___-___-_______'
                and    to_number(substr(j.FACTURA_ASOCIADA,1,3))>0
                and    to_number(substr(j.FACTURA_ASOCIADA,5,3))>0
                and    to_number(substr(j.FACTURA_ASOCIADA,9,7))>0;
             exception
                when others then
                  v_error:=  nvl(v_error,'')||'- Número de comprobante asociado con formato inválido.';
             end;
          end if;
          --nro_timbrado_asociado
          if j.TIMBRADO_ASOCIADO is null then
             v_error:=  nvl(v_error,'')||'- Es necesario definir un numero de timbrado asociado a la Nota de Crédito';
           end if;
         end if;

      end if;
   end if;
   if v_error is null then
        -- si no hay errror guardar el registro en la tabla final y actualizar en el temporal
        begin
			insert into CB_RG_90( tipo_registro,
							  cod_tip_documento,
							  nro_identificador,
							  raz_social,
							  cod_tipo_comprobante,
							  fecha_emision,
							  nro_timbrado,
							  nro_comprobante,
							  monto_gravado_10,
							  monto_gravado_5,
							  monto_exento,
							  monto_total,
							  condicion,
							  moneda_extranjera,
							  imputa_iva,
							  imputa_ire,
							  imputa_irp_rsp,
							  no_imputa,
							  factura_asociada,
							  timbrado_asociado,
							  fec_proceso,
							  periodo,
							  generado,
							  usu_insercion,
							  fec_insercion,
							  usu_modificacion,
							  fec_modificacion)
			values (j.tipo_registro,
					v_tipo_identificador,
					j.NRO_IDENTIFICADOR,
					j.RAZ_SOCIAL,
					j.cod_tipo_comprobante,
					j.fecha_emision, 
					v_timbrado,
					j.nro_comprobante,
					v_monto_gravado_10, 
					v_monto_gravado_5, 
					V_MONTO_EXENTO, 
					V_MONTO_TOTAL,
					v_condicion,
					v_moneda_extranjera,
					v_imputa_iva,
					'N' /*j.imputa_ire*/, 
					'N'/*j.imputa_irp_rsp*/, 
					v_no_imputa,
					j.factura_asociada, 
					j.timbrado_asociado, 
					TRUNC(SYSDATE), 
					TO_CHAR(J.fecha_emision,'mm/yyyy'),
					null,
					USER,
					SYSDATE,
					USER,
					SYSDATE);
		exception
			when DUP_VAL_ON_INDEX then
			   V_ERROR := 'Registro duplicado';
			when others then
			   V_ERROR := 'Error al insertar registro en la tabla CB_RG_90. '||sqlerrm;
		end;
  end if;
  update CB_RG_90_IMP T
  set T.procesado  = 'S',
	  T.ERROR      = V_ERROR
  where t.rowid = j.rowid;
  commit;
  end loop;
END;
/

