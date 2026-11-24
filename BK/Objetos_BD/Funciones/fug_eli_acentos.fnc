create or replace function it.fug_eli_acentos(p_cadena VARCHAR2)
  RETURN VARCHAR2 IS
  v_cadena VARCHAR2(4000);
Begin
  IF p_cadena IS NOT NULL THEN
    v_cadena := translate(p_cadena,
                          'αινσϊΰθμςωδλοφόΑΙΝΣΪέΔΛΟΦάΐΘΜÒΩ,+΄~|°Ίª¬!"#$%&/()=?΅Ώ*¨{}^`Ώ[]:;><Ηη%',
                          'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
    v_cadena := translate(v_cadena,
                          'βκξτϋΒΚΞΤΫΓγΠΥΧΨέήίεζπυψχύώÿAa\Ά£¤¥¦§©«®―±²³µ¶·ΈΉΊ»Ό½ΎΏ',
                          'aeiouAEIOUAaDO     a  o  y yAa                           ');
    v_cadena := translate(v_cadena, '''', '  ');
  END IF;
  RETURN(v_cadena);

end fug_eli_acentos;
/

