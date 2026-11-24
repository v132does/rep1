create or replace function it.fue_obt_val_rango
  (p_nmrefer in varchar2,
   p_dcvalor in varchar2,
   p_tpcampo in varchar2)
 RETURN varchar2 Is
  vString VarChar2(300):= p_dcvalor;
  vLength Number(10)   := nvl(Length(vString),0);
  vPosicion Number(10) := 1;
  vDesde VarChar2(100);
  vHasta VarChar2(100);
  vTipo VarChar2(100);
  v_retorno varchar2(300);
  v_or varchar2(2) := null;
  --
  Procedure lp_obt_desde_hasta ( pString In VarChar2,
                                    pPosicion In Out Number,
                                    pTipo In Out VarChar2,
                                    pDesde In Out VarChar2,
                                    pHasta In Out VarChar2 ) Is
    vLength Number(10) := Length(pString);
    vCaracter VarChar2(1);
    vPos1 Number(10);
    vPos2 Number(10);
    vPos3 Number(10);
    vPosx Number(10);
  Begin
  	vPos1 := Instr(pString,' ',pPosicion);
    pTipo := LTrim(RTrim(Substr(pString,pPosicion,vPos1-pPosicion)));
    vPos2 := Instr(pString,' ',vPos1+1);
    -- veo sino es palabra entre apostrofes
    vPosx := Instr(pString,'''',vPos1+1);  -- posicion de apostrofe
    if vPosx < vPos2 then -- hay un apostrofe, debo buscar el sgte.
    	 vPosx := Instr(pString,'''',vPosx+1);
    	 if vPosx > 0 then
    	 	  vPos2 := vPosx+1;
    	 end if;
    end if;
    --
    If vPos2 = 0 Then
      pDesde := LTrim(RTrim(Substr(pString,vPos1+1)));
      pPosicion := vLength+1;
    Else
      pDesde := LTrim(RTrim(Substr(pString,vPos1+1,vPos2-vPos1)));
      If pTipo = 'Entre' Then
        vPos3 := Instr(pString,CHR(243),vPos2); -- busco la letra ó
        If vPos3 = 0 Then
          pHasta := LTrim(RTrim(Substr(pString,vPos2+3)));
          pPosicion := vLength+1;
        Else
          pHasta := LTrim(RTrim(Substr(pString,vPos2+3,vPos3-(vPos2+4))));
          pPosicion := vPos3+2;
        End If;
      Else
        pPosicion := vPos2+3;
      End If;
    End If;

  End;

  --
Begin
  Loop
    Exit When vPosicion >= vLength;
    vTipo := Null;
    vDesde := Null;
    vHasta := Null;
    -- Obtengo el valor desde y hasta de la cadena recibida ---------
    lp_obt_desde_hasta (vString,vPosicion,vTipo,vDesde,vHasta );
    if    vtipo = 'Mayor_a' then
    	    vtipo := '>';
    elsif vtipo = 'Menor_a' then
    	    vtipo := '<';
    elsif vtipo = 'Mayor_o_Igual_a' then
    	    vtipo := '>=';
    elsif vtipo = 'Menor_o_Igual_a' then
    	    vtipo := '<=';
    elsif vtipo = 'Igual_a' then
    	    vtipo := '=';
    elsif vtipo = 'Entre' then
    	    vtipo := 'Between';
    End if;
    if p_tpcampo = 'S' then -- tipo alfabetico
    	 if vtipo = '=' then -- verifico si tiene
    	 	  if instr(vDesde,'%') > 0 or instr(vDesde,'_') > 0 then
    	 	  	 vtipo := 'like';
    	 	  end if;
    	 end if;
    	 v_retorno := v_retorno ||' '||v_or||' '||p_nmrefer||' '||vtipo||' '||vDesde;
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and '||vhasta;
    	 end if;
    elsif p_tpcampo = 'N' then -- tipo numerico
    	 v_retorno := v_retorno ||' '||v_or||' '||p_nmrefer||' '||vtipo||' '||vDesde;
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and ' || vhasta;
    	 end if;
    elsif p_tpcampo = 'F' then -- tipo fecha
     	 v_retorno := v_retorno ||' '||v_or||' '||p_nmrefer||' '||vtipo||' to_date('||vDesde||','||chr(39)||'dd/mm/yyyy'||chr(39)||')';
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and to_date(' || vhasta ||','||chr(39)||'dd/mm/yyyy'||chr(39)||')';
    	 end if;
    end if;
    v_or := 'OR';
  End Loop;
  if trim(v_retorno) is not null then
     v_retorno := ' ('||trim(v_retorno)||')';
  end if;   
  return v_retorno;
End;
/

