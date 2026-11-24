CREATE OR REPLACE FUNCTION IT.FUE_OBT_VAL_LISTA
 (P_NMREFER IN VARCHAR2,
  P_DCVALOR IN VARCHAR2,
  P_TPCAMPO IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
  vString VarChar2(300) := p_dcvalor;
  vLength Number(10) := nvl(Length(vString),0);
  vPosicion Number(10) := 1;
  vValue VarChar2(100);
  vLabel VarChar2(100);
  v_retorno varchar2(400) := p_nmrefer||' IN (';
  v_or varchar2(02) := null;
  --
  /* Obtener valores de puntaje. */
  PROCEDURE lp_OBT_COD_DES
   (PSTRING IN VARCHAR2
   ,PPOSICION IN OUT NUMBER
   ,PVALUE IN OUT VARCHAR2
   ,PLABEL IN OUT VARCHAR2
   )
   IS
  begin
  declare
    vLength Number(10) := Length(pString);
    vCaracter VarChar2(1);
    vPos1 Number(10);
    vPos2 Number(10);
  Begin
    vPos1 := Instr(pString,'-',pPosicion);
    pValue := Substr(pString,pPosicion,vPos1-pPosicion);
    vPos2 := Instr(pString,CHR(243),pPosicion) - 1;
    If vPos2 > 0  Then
      pLabel := LTrim(RTrim(Substr(pString,vPos1+1,vPos2-vPos1-1)));
      pPosicion := vPos2+3;
    Else
      pLabel := LTrim(RTrim(Substr(pString,vPos1+1,(vLength+1)-vPos1-1)));
      pPosicion := vLength+1;
    End If;
    plabel := nvl(plabel,' ');
  End; 
  end;  
  --
Begin
if instr(p_nmrefer,'&CODIGO') > 0 then
	v_retorno := null;
  IF instr(p_dcvalor,chr(243)) > 0 then -- existe una relacion or
     v_retorno := ' (';
  end if;
  Loop
    Exit When vPosicion > vLength;
    vValue := Null;
    vLabel := Null;
    -- Obtengo el codigo y descripcion del valor en la cadena  -------
    LP_OBT_COD_DES (vString,vPosicion,vValue,vLabel);
    v_retorno := v_retorno ||' '||v_or;
    v_retorno := v_retorno ||' '||replace(p_nmrefer,'&CODIGO',chr(39) ||vValue || chr(39))||' = '||chr(39) ||'S'|| chr(39);
    v_or := 'OR';
  End Loop;
  IF instr(p_dcvalor,chr(243)) > 0 then -- existe una relacion or
     v_retorno := v_retorno||')';
  end if;
else
  Loop
    Exit When vPosicion > vLength;
    vValue := Null;
    vLabel := Null;
    -- Obtengo el codigo y descripcion del valor en la cadena  -------
    LP_OBT_COD_DES (vString,vPosicion,vValue,vLabel);
    if p_tpcampo = 'S' then -- tipo alfabetico
    	 v_retorno := v_retorno || chr(39) ||vValue || chr(39) || ',';
    elsif p_tpcampo = 'N' then -- tipo numerico
    	 v_retorno := v_retorno || vValue || ',';
    elsif p_tpcampo = 'F' then -- tipo fecha
    	 v_retorno := v_retorno || 'to_date('||vValue||',''DD/MM/YYYY''),';
    end if;
  End Loop;
  v_retorno := substr(v_retorno,1,length(v_retorno)-1)||')';
  if trim(v_retorno) is not null then
     v_retorno := ' ('||trim(v_retorno)||')';
  end if;     
end if;
return v_retorno;
End;
/

