CREATE OR REPLACE FUNCTION IT.FUJ_OBT_TEX_CAR_USO_ATM ( p_nro_cuenta in varchar2,
                                                    p_operacion in varchar2,
                                                    p_bco_atm in varchar2,
                                                    p_cod_entidad in number
                                                   ) return varchar2 is
  -- MDPMATNT-1 -- Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016
  v_texto             varchar2(408);
  v_linea             varchar2(100);
  V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_car_mas_iva       GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_gru_transaccion   number; 
  v_ntr_atm           varchar2(1); 
  v_cod_ban_fusion    number(3) := fug_obt_cod_ban_fusion; 
  
/* DYDMR-5533  
  function lf_exi_banco (p_cod_banco number) return varchar2 is
     v_exi_banco varchar2(1) := 'N';
   begin
     --WA: 06/08/2014 Buscamos inicialmente si es financiera
     begin
       select 'S'
        into v_exi_banco
         from ge_par_entes p, ge_entes e
        where p.parametro = 'COD_ENT_FINANCIERA'
          and p.cod_ente = e.cod_ente
          and p.val_parametro=p_cod_banco
          and e.tipo = 'FI';
     exception
        when no_data_found then
          v_exi_banco:='N';
        when others then
          v_exi_banco:='N';
     end;
     if nvl(v_exi_banco,'N')= 'N' then
       begin
        Select 'S'
           into v_exi_banco
           from ge_bancos
          where cod_banco = p_cod_banco
               and estado = 'A'
               and ubicacion = 'L';
        Exception
          When NO_DATA_FOUND then
             return v_exi_banco;
        end;
     end if;
     --
     return v_exi_banco;
   end lf_exi_banco;*/
   --
   
begin
/*
-- Transacciones Bancard --
02 CONSULTA DE SALDOS
52 CONSULTA DE SALDO EN EL EXTRANJERO
05 ATM-EXTRACCION EFECTIVO
55 EXTRACCION ATM EN EL EXTRANJERO
06 CONSULTA DE EXTRACTO

-- Grupos de Transacciones --
51	Extracciones nuestro ATM
52	Extracciones otro ATM
53	Consultas nuestro ATM
54	Consultas otro ATM
57	Extracciones ATM extranjero
58	Consultas ATM extranjero.
55	Consultas Extracto nuestro ATM.
56	Consultas Extracto otro ATM.
*/
/*  
  if to_number(p_operacion) in (2, 52) then -- Consulta de Saldo
     if to_number(p_operacion) = 52 then 
       v_gru_transaccion := 58;	-- 58	= Consultas atm extranjero.
     -- Verifica si el ATM es de la Entidad --
     elsif to_number(p_bco_atm) = p_cod_entidad then 
       v_gru_transaccion := 53;	-- 53	= Consultas nuestro atm
     else
       v_gru_transaccion := 54; -- 54	= Consultas otro atm
     end if;
  elsif to_number(p_operacion) in (5, 55) Then -- Extraccion
     if to_number(p_operacion) = 55 then 
       v_gru_transaccion := 57;	-- 57	Extracciones atm extranjero
     -- Verifica si el ATM es de la Entidad --
     elsif to_number(p_bco_atm) = p_cod_entidad then 
       v_gru_transaccion := 51;	-- 51	= Extracciones nuestro atm
     else
       v_gru_transaccion := 52; -- 52	= Extracciones otro atm
     end if;   
  end if;
*/
  
  if ((to_number(p_bco_atm) = p_cod_entidad) or 
      (to_number(p_bco_atm) = v_cod_ban_fusion)) then
    v_ntr_atm := 'S';
  else
    v_ntr_atm := 'N';
  end if;
  
  /* -- DYDMR-5533
  if lf_exi_banco(p_bco_atm) != 'S' then
    v_ntr_atm := 'S';
  end if;
  */
  
  begin
    select distinct a.cod_gru_transaccion
      into v_gru_transaccion
      from gv_gru_tra_cob_car_atm a
     where to_number(a.cod_tra_bancard) = to_number(p_operacion)
       and a.ind_atm_propio = v_ntr_atm;
  exception
    when others then
      v_gru_transaccion := null;
  end;

  if p_nro_cuenta is not null and v_gru_transaccion is not null then
    pra_obt_cob_car_uso_atm( p_nro_cuenta,
                             v_gru_transaccion,
                             v_val_cargo,
                             v_val_impuesto );                     
    -- Armar el texto -- 
    v_car_mas_iva := nvl(v_val_cargo,0) + nvl(v_val_impuesto,0);
    
/*
ESPAÑOL
"Estimado cliente, la transacción seleccionada está sujeta a un cargo de Gs. (aquí habrá un campo de monto) IVA INCLUIDO, según tarifario vigente.
¿Desea continuar?".

INGLÉS
"Dear Client, the selected transaction is subject to a fee of Gs (X) taxes included, acording to the current rates. ¿Do you wish to continue?"

PORTUGUÉS
"Prezado cliente, a operação selecionada está sujeita a uma taxa de (Monto) imposto incluído, de acordo a tarifa em vigor. ¿Deseja continuar?."
*/
    
    if nvl(v_car_mas_iva,0) > 0 then
      /*v_linea := 'Estimado cliente, el costo de la ';
      v_texto := v_texto || rpad(v_linea,34,' ');
      v_linea := 'Transaccion es de '||ltrim(to_char(v_car_mas_iva,'999G999D00'))||' Gs. ';
      v_texto := v_texto || rpad(v_linea,34,' ');
      v_linea := 'que sera debitada de su cuenta.';
      v_texto := v_texto || rpad(v_linea,34,' ');*/
      
      v_linea := 'Estimado cliente, la transaccion ';
      v_texto := v_texto || rpad(v_linea,34,' ');
      
      v_linea := 'seleccionada está sujeta a un ';
      v_texto := v_texto || rpad(v_linea,34,' ');
      
      v_linea := 'cargo de Gs. '||ltrim(to_char(v_car_mas_iva,'999G999D00'))||' IVA ';
      v_texto := v_texto || rpad(v_linea,34,' ');
      
      v_linea := 'INCLUIDO, segun tarifario vigente.';
      v_texto := v_texto || rpad(v_linea,34,' ');
      
      v_linea := '¿Desea continuar?';
      v_texto := v_texto || rpad(v_linea,34,' ');
      
    end if;
    
  end if;
   
  return nvl(v_texto,' ');
  
end fuj_obt_tex_car_uso_atm;
/

