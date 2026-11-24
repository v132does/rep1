CREATE OR REPLACE FUNCTION IT.FUE_OBT_VAL_MULTIPLE
 (/*P_CDCAMPO IN VARCHAR2
 ,*/P_NMREFER IN VARCHAR2
 ,P_DCVALOR IN VARCHAR2
 ,P_TPCAMPO IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
  vString VarChar2(300) := p_dcvalor;
  vLength Number(10)    := nvl(Length(vString),0);
  vPosicion Number(10)  := 1;
  vCountReg Number(10)  := 1;
  vLabel VarChar2(100);
  vDesde VarChar2(100);
  vHasta VarChar2(100);
  vTipo VarChar2(100);
  vValue VarChar2(5);
  v_retorno varchar2(400) := null;
  v_or varchar2(02) := null;
  ---
  PROCEDURE LP_OBT_VAL_RANGO
   (PSTRING IN VARCHAR2
   ,PPOSICION IN OUT NUMBER
   ,PVALUE IN OUT VARCHAR2
   ,PLABEL IN OUT VARCHAR2
   ,PTIPO IN OUT VARCHAR2
   ,PDESDE IN OUT VARCHAR2
   ,PHASTA IN OUT VARCHAR2
   )
   IS
  begin
  declare
    vLength Number(10) := Length(pString);
    vCaracter VarChar2(1);
    vPos1 Number(10);
    vPos2 Number(10);
    vPos3 Number(10);
    vPos4 Number(10);
    vPos5 Number(10);
  Begin
    vPos1  := Instr(pString,'-',pPosicion);
    pValue := Substr(pString,pPosicion,vPos1-pPosicion);
    vPos2  := Instr(pString,' ',pPosicion);
    pLabel := LTrim(RTrim(Substr(pString,vPos1+1,vPos2-vPos1-1)));
    vPos3 := Instr(pString,' ',vpos2+1);
    pTipo := LTrim(RTrim(Substr(pString,vPos2+1,vPos3-(vPos2+1))));
    vPos4 := Instr(pString,' ',vPos3+1);
    If vPos4 = 0  Then
      pDesde := LTrim(RTrim(Substr(pString,vPos3+1)));
      pPosicion := vLength+1;
    Else
      pDesde := LTrim(RTrim(Substr(pString,vPos3+1,vPos4-(vPos3+1))));
      If pTipo = 'Entre' Then
        vPos5 := Instr(pString,CHR(243),vPos4);
        If vPos5 = 0 Then
          pHasta := LTrim(RTrim(Substr(pString,vPos4+3)));
          pPosicion := vLength+1;
        Else
          pHasta := LTrim(RTrim(Substr(pString,vPos4+3,vPos5-(vPos4+4))));
          pPosicion := vPos5+2;
        End If;
      Else
        pPosicion := vPos4+3;
      End If;
    End If;
  end;
  End;
  
  ---
Begin
  Loop
    Exit When vPosicion > vLength;
    vValue := Null;
    vLabel := Null;
    vDesde := Null;
    vHasta := Null;
    vTipo := Null;
    -- obtengo los datos de la cadena recibida ---------------------------------------
    LP_OBT_VAL_RANGO ( vString,vPosicion,vValue,vLabel,vTipo,vDesde,vHasta );
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
    	 v_retorno := v_retorno ||' '||v_or;
     	 v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39))||' '||vtipo||' '||chr(39) ||vDesde || chr(39);
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and '||chr(39) ||vhasta || chr(39);
    	 end if;
    elsif p_tpcampo = 'N' then -- tipo numerico
    	 v_retorno := v_retorno ||' '||v_or;
     	 v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',vValue)||' '||vtipo||' '||vDesde;
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and ' || vhasta;
    	 end if;
    elsif p_tpcampo = 'F' then -- tipo fecha
    	 v_retorno := v_retorno ||' '||v_or;
     	 v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39))||' '||vtipo||' to_date('||vDesde||',''DD/MM/YYYY'')';
    	 if vtipo = 'Between' then
    	 	  v_retorno := v_retorno||' and to_date(' || vhasta ||')';
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

