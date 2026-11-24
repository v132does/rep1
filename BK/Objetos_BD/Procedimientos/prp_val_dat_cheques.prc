create or replace procedure it.PRP_VAL_DAT_CHEQUES(P_COD_BANCO IN NUMBER,
                                                P_CTA_LIBRADORA VARCHAR2, 
                                                P_NRO_CHEQUE IN NUMBER,
                                                p_nro_referencia in varchar2,
                                                p_mensaje in out varchar2,
                                                p_cod_moneda in varchar2) is
	v_nrcuent ge_che_custodias.cta_libradora%type;
	v_mensaje varchar2(100);
	v_cdofcam number(3);
	v_cdcasam number(3);
  v_estado  varchar2(1);
  v_cod_banco number(5);
  v_cod_entidad ge_par_generales.cod_entidad%type;
Begin
	If p_nro_cheque is not null Then
		 -- Verifica que no exista --
		 Select nro_referencia, decode(tip_servicio, 'D', 'propuesta', 'G', 'propuesta', 'cuenta')
		   into v_nrcuent, v_mensaje
		   from ge_che_custodias 
		  where cod_banco     = p_cod_banco
		    and cta_libradora = p_cta_libradora 
		    and nro_cheque    = p_nro_cheque;
     If v_nrcuent != p_nro_referencia then
    		p_mensaje := ('Este cheque ya existe para la '||v_mensaje||': '||v_nrcuent);
     End if;
	End if;
Exception
		When NO_DATA_FOUND Then 
					--- Si no existe verifica los datos de la cuenta.
          v_cod_entidad := pag_gen.fu_obt_cod_entidad;
          If substr(v_cod_entidad,1,2) = 10 then
             v_cod_banco := substr(v_cod_entidad, 3, 2);
          Else 
             v_cod_banco := -1;
          End if;
          ---
      		If p_cod_banco = v_cod_banco then
						v_estado := pac_che.FU_OBT_EST_CHE(p_cta_libradora, p_nro_cheque, p_mensaje);
            If p_mensaje is null then
            	If NVL(v_estado,'O') not in ('C','E','G') THEN
        	   		 select decode(v_estado,'O','Orden no Pago',
        	   		                      'P','Pagado',
        	   		                      'A','Anulado',
        	   		                      'Desconocido: '||v_estado )
          			   into p_mensaje
          			   from dual;
                 p_mensaje := 'El estado del cheque '||p_nro_cheque||' es '||p_mensaje;
              else
                 -- veo la moneda de la cuenta  
                 declare
                    v_cod_moneda varchar2(5);
                 begin
                    select cod_moneda 
                      into v_cod_moneda
                      from ge_cuentas
                     where nro_cuenta = p_cta_libradora;
                    if v_cod_moneda <> p_cod_moneda then
                       p_mensaje := 'Moneda de la cuenta libradora no coincide con la Solicitud.';
                    end if;    
                 exception
                    when no_data_found then
                       p_mensaje := 'Cta. libradora no existe!';    
                 end; 
              End If;
            End If;
					End If;
end;
/

